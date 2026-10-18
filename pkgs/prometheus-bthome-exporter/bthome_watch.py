#!/usr/bin/env python3
"""Periodically display BTHome devices ordered by signal strength."""

from __future__ import annotations

import argparse
import asyncio
import math
import sys
import time
from dataclasses import dataclass
from typing import Any

from bleak import BleakError

from bthome_scan import BthomeScanner

RSSI_FLOOR = -100
RSSI_CEILING = 0
BAR_STEP_DBM = 5
BAR_WIDTH = (RSSI_CEILING - RSSI_FLOOR) // BAR_STEP_DBM


@dataclass
class DeviceSignal:
    """Signal strength and last-seen time of one BTHome device."""

    address: str
    name: str
    rssi: float | None = None
    last_seen: float | None = None


class DeviceTracker:
    """Latest signal strength and last-seen time of each BTHome device."""

    def __init__(self) -> None:
        """Create an empty tracker."""
        self._devices: dict[str, DeviceSignal] = {}

    def update(self, record: dict[str, Any]) -> None:
        """Apply a decoded packet record.

        Args:
            record: Record emitted by BthomeScanner.
        """
        address = record["address"]
        name = record["title"] or record["name"] or address
        device = self._devices.get(address)
        if device is None:
            device = DeviceSignal(address=address, name=name)
            self._devices[address] = device
        device.name = name
        device.rssi = record.get("rssi")
        device.last_seen = record["timestamp"]

    def snapshot(self) -> list[DeviceSignal]:
        """Return copies of the tracked devices sorted by address.

        Returns:
            A list of independent device entries.
        """
        return [
            DeviceSignal(
                address=device.address,
                name=device.name,
                rssi=device.rssi,
                last_seen=device.last_seen,
            )
            for device in sorted(
                self._devices.values(), key=lambda device: device.address
            )
        ]


def format_bar(rssi: float) -> str:
    """Render a signal strength bar.

    Args:
        rssi: RSSI in dBm, clamped to the supported range.

    Returns:
        A bar of up to BAR_WIDTH hashes, one hash per BAR_STEP_DBM.
    """
    clamped = max(RSSI_FLOOR, min(RSSI_CEILING, rssi))
    return "#" * round((clamped - RSSI_FLOOR) / BAR_STEP_DBM)


def format_age(now: float, last_seen: float | None) -> str:
    """Render how long ago a device was last seen.

    Args:
        now: Current Unix timestamp.
        last_seen: Last-seen Unix timestamp, or None if unknown.

    Returns:
        A human-readable age string.
    """
    if last_seen is None:
        return "last seen ?"
    seconds = max(0, int(now - last_seen))
    return f"last seen {seconds} s ago"


def format_report(devices: list[DeviceSignal], now: float) -> str:
    """Render a table of devices sorted by name.

    Args:
        devices: Devices to render.
        now: Current Unix timestamp used for the last-seen column.

    Returns:
        A table with one row per device that has a finite RSSI.
    """
    visible = [
        device
        for device in devices
        if device.rssi is not None and math.isfinite(device.rssi)
    ]
    if not visible:
        return "No BTHome devices seen yet."

    visible.sort(key=lambda device: (device.name.casefold(), device.address))
    name_width = max(20, max(len(device.name) for device in visible))
    address_width = max(17, max(len(device.address) for device in visible))
    lines = [
        f"{'Name':<{name_width}}  {'Address':<{address_width}}  "
        f"{'RSSI':>9}  {'Signal':<{BAR_WIDTH}}  Last seen"
    ]
    for device in visible:
        bar = format_bar(device.rssi)
        lines.append(
            f"{device.name:<{name_width}}  {device.address:<{address_width}}  "
            f"{device.rssi:>5.0f} dBm  {bar:<{BAR_WIDTH}}  "
            f"{format_age(now, device.last_seen)}"
        )
    return "\n".join(lines)


def positive_float(value: str) -> float:
    """Parse a strictly positive floating point number for argparse.

    Args:
        value: Raw command line value.

    Returns:
        The parsed number.

    Raises:
        argparse.ArgumentTypeError: If value is not a positive number.
    """
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return number


def build_arg_parser() -> argparse.ArgumentParser:
    """Build the command line argument parser.

    Returns:
        The configured argument parser.
    """
    parser = argparse.ArgumentParser(
        prog="bthome-watch",
        description="Show BTHome devices ordered by signal strength.",
    )
    parser.add_argument(
        "--interval",
        type=positive_float,
        default=2.0,
        metavar="SECONDS",
        help="refresh interval in seconds (default: 2)",
    )
    parser.add_argument(
        "--scan-time",
        type=positive_float,
        default=10.0,
        metavar="SECONDS",
        help="scan duration before printing the report in --once mode (default: 10)",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="scan once and print one report, then exit",
    )
    return parser


def render(tracker: DeviceTracker, now: float | None = None) -> str:
    """Render one report from the tracked devices.

    Args:
        tracker: Tracker holding the latest device signals.
        now: Current Unix timestamp, defaults to the current time.

    Returns:
        The rendered device table.
    """
    return format_report(tracker.snapshot(), time.time() if now is None else now)


async def wait_for_scan(scan_task: asyncio.Task[None], timeout: float) -> None:
    """Wait up to timeout while propagating early scanner failures.

    Args:
        scan_task: Running Bluetooth scanner task.
        timeout: Number of seconds to wait.

    Raises:
        BleakError: If the scanner stops before the timeout expires.
    """
    done, _ = await asyncio.wait({scan_task}, timeout=timeout)
    if done:
        scan_task.result()
        raise BleakError("Bluetooth scanner stopped unexpectedly")


async def watch(args: argparse.Namespace) -> None:
    """Scan for BTHome advertisements and print reports.

    Args:
        args: Parsed command line arguments.

    Raises:
        BleakError: If Bluetooth scanning fails.
    """
    tracker = DeviceTracker()
    scanner = BthomeScanner(tracker.update)
    stop = asyncio.Event()
    scan_task = asyncio.create_task(scanner.run(stop))
    try:
        if args.once:
            await wait_for_scan(scan_task, args.scan_time)
            print(render(tracker), flush=True)
            return
        while True:
            await wait_for_scan(scan_task, args.interval)
            if sys.stdout.isatty():
                sys.stdout.write("\033[2J\033[H")
            print(render(tracker), flush=True)
    finally:
        stop.set()
        await scan_task


def main() -> int:
    """Run the watcher.

    Returns:
        Process exit status: 0 on success, 1 on Bluetooth errors and 130 when
        interrupted with Ctrl-C.
    """
    args = build_arg_parser().parse_args()
    try:
        asyncio.run(watch(args))
    except KeyboardInterrupt:
        return 130
    except BleakError as exc:
        print(f"Bluetooth error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
