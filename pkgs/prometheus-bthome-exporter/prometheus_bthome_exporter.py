#!/usr/bin/env python3
"""Prometheus exporter for BTHome BLE advertisements."""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
import threading
from collections.abc import Iterator
from dataclasses import dataclass, field
from typing import Any

from bleak import BleakError
from prometheus_client import REGISTRY, start_http_server
from prometheus_client.core import CounterMetricFamily, GaugeMetricFamily, Metric
from prometheus_client.registry import Collector, CollectorRegistry

from bthome_scan import BthomeScanner

LOGGER = logging.getLogger("prometheus-bthome-exporter")


@dataclass
class DeviceState:
    """Latest decoded state of one BTHome device."""

    address: str
    name: str
    rssi: float | None
    timestamp: float
    values: dict[str, tuple[float, str]] = field(default_factory=dict)
    binary_values: dict[str, float] = field(default_factory=dict)
    events: dict[tuple[str, str], int] = field(default_factory=dict)


class DeviceRegistry:
    """Thread-safe store of the latest state of each BTHome device."""

    def __init__(self) -> None:
        """Create an empty registry."""
        self._lock = threading.Lock()
        self._devices: dict[str, DeviceState] = {}

    def update(self, record: dict[str, Any]) -> bool:
        """Apply a decoded packet record to the registry.

        Numeric and binary values present in the packet replace earlier
        values. Values absent from the packet are retained. Event counters
        are incremented.

        Args:
            record: Record emitted by BthomeScanner.

        Returns:
            True if the record belongs to a device not seen before.
        """
        address = record["address"]
        name = record["title"] or record["name"] or address
        values = {}
        for value in record["values"]:
            native_value = value["value"]
            if isinstance(native_value, bool) or not isinstance(
                native_value, (int, float)
            ):
                continue
            values[value["key"]] = (float(native_value), value["unit"] or "")

        binary_values = {}
        for value in record["binary_values"]:
            native_value = value["value"]
            if isinstance(native_value, bool):
                binary_values[value["key"]] = 1.0 if native_value else 0.0

        events = {}
        for event in record["events"]:
            key = (str(event["key"]), str(event["type"]))
            events[key] = events.get(key, 0) + 1

        with self._lock:
            state = self._devices.get(address)
            is_new = state is None
            if state is None:
                state = DeviceState(
                    address=address,
                    name=name,
                    rssi=record.get("rssi"),
                    timestamp=record["timestamp"],
                )
                self._devices[address] = state
            state.name = name
            state.rssi = record.get("rssi")
            state.timestamp = record["timestamp"]
            state.values.update(values)
            state.binary_values.update(binary_values)
            for key, count in events.items():
                state.events[key] = state.events.get(key, 0) + count
        return is_new

    def snapshot(self) -> list[DeviceState]:
        """Return a copy of the current device states sorted by address.

        Returns:
            A list of independent device states.
        """
        with self._lock:
            states = sorted(self._devices.values(), key=lambda state: state.address)
            return [
                DeviceState(
                    address=state.address,
                    name=state.name,
                    rssi=state.rssi,
                    timestamp=state.timestamp,
                    values=dict(state.values),
                    binary_values=dict(state.binary_values),
                    events=dict(state.events),
                )
                for state in states
            ]


class BthomeCollector(Collector):
    """Prometheus collector exposing the latest BTHome device state."""

    def __init__(self, registry: DeviceRegistry) -> None:
        """Create a collector backed by the given registry.

        Args:
            registry: Registry holding the latest device states.
        """
        self._registry = registry

    def collect(self) -> Iterator[Metric]:
        """Yield the current BTHome metrics.

        Returns:
            Metric families for sensor values, binary sensors, events, RSSI
            and last-seen timestamps.
        """
        sensors = GaugeMetricFamily(
            "bthome_sensor_value",
            "Last decoded BTHome sensor value.",
            labels=["address", "name", "sensor", "unit"],
        )
        binary_sensors = GaugeMetricFamily(
            "bthome_binary_sensor",
            "Last decoded BTHome binary sensor state.",
            labels=["address", "name", "sensor"],
        )
        events = CounterMetricFamily(
            "bthome_events",
            "BTHome events received since the exporter started.",
            labels=["address", "name", "event", "type"],
        )
        rssi = GaugeMetricFamily(
            "bthome_rssi_dbm",
            "RSSI of the last BTHome advertisement.",
            labels=["address", "name"],
        )
        last_seen = GaugeMetricFamily(
            "bthome_last_seen_timestamp_seconds",
            "Unix timestamp of the last BTHome advertisement.",
            labels=["address", "name"],
        )

        for device in self._registry.snapshot():
            for sensor, (value, unit) in sorted(device.values.items()):
                sensors.add_metric(
                    [device.address, device.name, sensor, unit],
                    value,
                )
            for sensor, value in sorted(device.binary_values.items()):
                binary_sensors.add_metric(
                    [device.address, device.name, sensor],
                    value,
                )
            for (event, event_type), count in sorted(device.events.items()):
                events.add_metric(
                    [device.address, device.name, event, event_type],
                    count,
                )
            if device.rssi is not None:
                rssi.add_metric([device.address, device.name], device.rssi)
            last_seen.add_metric(
                [device.address, device.name],
                device.timestamp,
            )

        yield sensors
        yield binary_sensors
        yield events
        yield rssi
        yield last_seen


def decode_bindkey(value: str) -> bytes:
    """Decode a 16-byte AES-CCM bindkey from hex.

    Args:
        value: 32 hex characters, surrounding whitespace is ignored.

    Returns:
        The bindkey as bytes.

    Raises:
        ValueError: If value is not a 16-byte hex string.
    """
    try:
        bindkey = bytes.fromhex(value)
    except ValueError as exc:
        raise ValueError("bindkey must be a hex string") from exc
    if len(bindkey) != 16:
        raise ValueError("bindkey must be 16 bytes (32 hex characters)")
    return bindkey


def read_bindkey_file(path: str) -> bytes:
    """Read a bindkey from a file.

    Args:
        path: Path to a file containing a 16-byte hex bindkey.

    Returns:
        The bindkey as bytes.

    Raises:
        OSError: If the file cannot be read.
        ValueError: If the file does not contain a valid bindkey.
    """
    with open(path, encoding="ascii") as file:
        return decode_bindkey(file.read())


def parse_bindkey(value: str) -> bytes:
    """Parse a bindkey for argparse.

    Args:
        value: Raw command line value.

    Returns:
        The bindkey as bytes.

    Raises:
        argparse.ArgumentTypeError: If value is not a 16-byte hex string.
    """
    try:
        return decode_bindkey(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def parse_bindkey_file(value: str) -> bytes:
    """Read a bindkey file for argparse.

    Args:
        value: Raw command line path.

    Returns:
        The bindkey as bytes.

    Raises:
        argparse.ArgumentTypeError: If the file cannot be read or does not
            contain a valid bindkey.
    """
    try:
        return read_bindkey_file(value)
    except (OSError, ValueError) as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def port_number(value: str) -> int:
    """Parse a TCP port for argparse.

    Args:
        value: Raw command line value.

    Returns:
        The parsed port number.

    Raises:
        argparse.ArgumentTypeError: If value is not a port number.
    """
    try:
        port = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if not 1 <= port <= 65535:
        raise argparse.ArgumentTypeError("must be between 1 and 65535")
    return port


def build_arg_parser() -> argparse.ArgumentParser:
    """Build the command line argument parser.

    Returns:
        The configured argument parser.
    """
    parser = argparse.ArgumentParser(
        prog="prometheus-bthome-exporter",
        description="Expose decoded BTHome BLE advertisements as Prometheus metrics.",
    )
    parser.add_argument(
        "--listen-address",
        default="127.0.0.1",
        metavar="ADDRESS",
        help="address the metrics HTTP server listens on (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--port",
        type=port_number,
        default=20006,
        metavar="PORT",
        help="port the metrics HTTP server listens on (default: 20006)",
    )
    bindkeys = parser.add_mutually_exclusive_group()
    bindkeys.add_argument(
        "--bindkey",
        type=parse_bindkey,
        default=None,
        metavar="HEX",
        help=(
            "16-byte AES-CCM key as 32 hex characters, used to decrypt "
            "encrypted packets (applied to all devices)"
        ),
    )
    bindkeys.add_argument(
        "--bindkey-file",
        type=parse_bindkey_file,
        default=None,
        metavar="PATH",
        help="file containing a 16-byte AES-CCM key as 32 hex characters",
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="log level (default: INFO)",
    )
    return parser


def handle_record(registry: DeviceRegistry, record: dict[str, Any]) -> None:
    """Apply a decoded BTHome packet record to the registry and log it.

    Args:
        registry: Registry holding the latest device states.
        record: Record emitted by BthomeScanner.
    """
    if registry.update(record):
        LOGGER.info(
            "Discovered BTHome device %s (%s)",
            record["address"],
            record["name"],
        )
    LOGGER.debug(
        "Packet from %s: values=%s binary_values=%s events=%s",
        record["address"],
        record["values"],
        record["binary_values"],
        record["events"],
    )


async def run(
    args: argparse.Namespace,
    bindkey: bytes | None,
    prometheus_registry: CollectorRegistry = REGISTRY,
) -> None:
    """Start the metrics server and scan for BTHome advertisements.

    Args:
        args: Parsed command line arguments.
        bindkey: AES-CCM key used for encrypted packets, or None.
        prometheus_registry: Registry the exporter registers its collector on.
    """
    registry = DeviceRegistry()
    prometheus_registry.register(BthomeCollector(registry))
    start_http_server(
        args.port,
        addr=args.listen_address,
        registry=prometheus_registry,
    )
    LOGGER.info("Serving metrics on %s:%s", args.listen_address, args.port)

    def handle(record: dict[str, Any]) -> None:
        handle_record(registry, record)

    scanner = BthomeScanner(handle, bindkey)
    await scanner.run()


def main() -> int:
    """Run the exporter.

    Returns:
        Process exit status: 0 on success, 1 on Bluetooth errors and 130 when
        interrupted with Ctrl-C.
    """
    args = build_arg_parser().parse_args()
    logging.basicConfig(
        level=args.log_level,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    bindkey = args.bindkey if args.bindkey is not None else args.bindkey_file
    try:
        asyncio.run(run(args, bindkey))
    except KeyboardInterrupt:
        return 130
    except BleakError as exc:
        LOGGER.error("Bluetooth error: %s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
