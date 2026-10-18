"""BLE scanning and BTHome advertisement decoding.

Shared by the Prometheus exporter and the bthome-watch terminal watcher.
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from bleak import BleakScanner
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from bthome_ble import BTHomeBluetoothDeviceData, SensorUpdate
from habluetooth import BluetoothServiceInfoBleak

V1_NON_ENCRYPTED_UUID = "0000181c-0000-1000-8000-00805f9b34fb"
V1_ENCRYPTED_UUID = "0000181e-0000-1000-8000-00805f9b34fb"
V2_UUID = "0000fcd2-0000-1000-8000-00805f9b34fb"

BTHOME_UUIDS = frozenset(
    {
        V1_NON_ENCRYPTED_UUID,
        V1_ENCRYPTED_UUID,
        V2_UUID,
    }
)

LOGGER = logging.getLogger("bthome-scan")


def normalize_uuid(value: str) -> str:
    """Return the canonical 128-bit lowercase form of a Bluetooth UUID.

    Args:
        value: A 16-bit, 32-bit, or 128-bit UUID string, with or without dashes.

    Returns:
        The UUID in the canonical lowercase 128-bit representation.

    Raises:
        ValueError: If value is not a valid UUID string.
    """
    compact = value.lower().replace("-", "")
    if len(compact) == 4:
        compact = "0000" + compact
    if len(compact) == 8:
        compact += "00001000800000805f9b34fb"
    return str(UUID(compact))


def bthome_service_data(advertisement: AdvertisementData) -> dict[str, bytes]:
    """Return the BTHome service data entries of an advertisement.

    Args:
        advertisement: Advertisement data reported by bleak.

    Returns:
        A dict of raw BTHome service data keyed by canonical 128-bit UUID.
        Entries with other or malformed UUIDs are omitted.
    """
    service_data = {}
    for key, value in advertisement.service_data.items():
        try:
            uuid = normalize_uuid(key)
        except ValueError:
            continue
        if uuid in BTHOME_UUIDS:
            service_data[uuid] = value
    return service_data


def is_encrypted(service_data: dict[str, bytes]) -> bool:
    """Return True if the BTHome service data uses an encrypted scheme.

    Args:
        service_data: BTHome service data keyed by canonical 128-bit UUID.

    Returns:
        True for the BTHome v1 encrypted UUID or a BTHome v2 packet with the
        encryption flag set, False otherwise.
    """
    for uuid, data in service_data.items():
        if uuid == V1_ENCRYPTED_UUID:
            return True
        if uuid == V2_UUID:
            return bool(data and data[0] & 0x01)
    return False


def parse_advertisement(
    parser: BTHomeBluetoothDeviceData,
    device: BLEDevice,
    advertisement: AdvertisementData,
    service_data: dict[str, bytes],
) -> dict[str, Any]:
    """Parse a BTHome advertisement into a JSON-serializable record.

    Args:
        parser: Parser instance holding the per-device state.
        device: Device the advertisement belongs to.
        advertisement: Advertisement data reported by bleak.
        service_data: BTHome service data keyed by canonical 128-bit UUID.

    Returns:
        A record with advertisement metadata, raw service data and the decoded
        sensor values, binary sensor values and events.

    Raises:
        Exception: Whatever bthome-ble raises for malformed or unsupported
            packets.
    """
    service_info = BluetoothServiceInfoBleak(
        name=device.name or advertisement.local_name or "",
        address=device.address,
        rssi=advertisement.rssi,
        manufacturer_data=advertisement.manufacturer_data,
        service_data=service_data,
        service_uuids=list(advertisement.service_uuids),
        source="local",
        device=device,
        advertisement=advertisement,
        connectable=False,
        time=time.time(),
        tx_power=advertisement.tx_power,
    )
    update = parser.update(service_info)
    encrypted = is_encrypted(service_data)
    return build_record(
        device,
        advertisement,
        service_data,
        update,
        encrypted=encrypted,
        decoded=not encrypted or parser.bindkey_verified,
    )


def build_record(
    device: BLEDevice,
    advertisement: AdvertisementData,
    service_data: dict[str, bytes],
    update: SensorUpdate,
    *,
    encrypted: bool,
    decoded: bool,
) -> dict[str, Any]:
    """Assemble a JSON-serializable record from a parser update.

    Args:
        device: Device the advertisement belongs to.
        advertisement: Advertisement data reported by bleak.
        service_data: BTHome service data keyed by canonical 128-bit UUID.
        update: Parsed sensor update returned by bthome-ble.
        encrypted: Whether the packet is encrypted.
        decoded: Whether the payload was decoded (plaintext packet or
            successful decryption).

    Returns:
        A record describing the packet and its decoded contents.
    """
    values = []
    for key, value in update.entity_values.items():
        description = update.entity_descriptions.get(key)
        unit = description.native_unit_of_measurement if description else None
        device_class = description.device_class if description else None
        values.append(
            {
                "key": key.key,
                "name": value.name,
                "value": value.native_value,
                "unit": str(unit) if unit else None,
                "device_class": str(device_class) if device_class else None,
            }
        )

    binary_values = []
    for key, value in update.binary_entity_values.items():
        description = update.binary_entity_descriptions.get(key)
        device_class = description.device_class if description else None
        binary_values.append(
            {
                "key": key.key,
                "name": value.name,
                "value": value.native_value,
                "device_class": str(device_class) if device_class else None,
            }
        )

    events = []
    for key, event in update.events.items():
        events.append(
            {
                "key": key.key,
                "name": event.name,
                "type": event.event_type,
                "properties": event.event_properties,
            }
        )

    now = time.time()
    return {
        "time": datetime.fromtimestamp(now, UTC).isoformat(timespec="milliseconds"),
        "timestamp": now,
        "address": device.address,
        "name": device.name or advertisement.local_name,
        "title": update.title,
        "rssi": advertisement.rssi,
        "encrypted": encrypted,
        "decoded": decoded,
        "service_data": {uuid: data.hex() for uuid, data in service_data.items()},
        "values": values,
        "binary_values": binary_values,
        "events": events,
    }


class BthomeScanner:
    """Scan for BLE advertisements and decode BTHome packets.

    Bleak reports every advertisement it sees. This scanner filters out
    non-BTHome advertisements, keeps one bthome-ble parser per device and
    forwards each decoded packet record to a callback.

    Args:
        callback: Called with every decoded packet record.
        bindkey: AES-CCM key used to decrypt encrypted packets, or None.
    """

    def __init__(
        self,
        callback: Callable[[dict[str, Any]], None],
        bindkey: bytes | None = None,
    ) -> None:
        self._callback = callback
        self._bindkey = bindkey
        self._parsers: dict[str, BTHomeBluetoothDeviceData] = {}

    def handle_advertisement(
        self,
        device: BLEDevice,
        advertisement: AdvertisementData,
    ) -> None:
        """Decode one advertisement and forward it to the callback.

        Advertisements without BTHome service data and packets that fail to
        parse are ignored so that a single malformed packet cannot stop a
        long-running scan.

        Args:
            device: Device the advertisement belongs to.
            advertisement: Advertisement data reported by bleak.
        """
        service_data = bthome_service_data(advertisement)
        if not service_data:
            return

        parser = self._parsers.get(device.address)
        if parser is None:
            parser = BTHomeBluetoothDeviceData(bindkey=self._bindkey)
            self._parsers[device.address] = parser

        try:
            record = parse_advertisement(
                parser, device, advertisement, service_data
            )
        except Exception as exc:  # A malformed packet must not stop scanning.
            LOGGER.warning(
                "%s: failed to parse BTHome packet: %s", device.address, exc
            )
            return

        self._callback(record)

    async def run(self, stop: asyncio.Event | None = None) -> None:
        """Scan for BTHome advertisements until stopped.

        Args:
            stop: Event that stops scanning once set. If None, scan until the
                task is cancelled.

        Raises:
            BleakError: If the Bluetooth scanner fails to start or stops.
        """
        scanner = BleakScanner(detection_callback=self.handle_advertisement)
        async with scanner:
            if stop is None:
                await asyncio.Event().wait()
            else:
                await stop.wait()
