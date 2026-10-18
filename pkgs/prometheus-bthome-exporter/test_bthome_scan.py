"""Tests for bthome_scan's advertisement parsing and scanning."""

import unittest
from unittest import mock

from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from bthome_ble import BTHomeBluetoothDeviceData

import bthome_scan

BTHOME_V2_UUID = "0000fcd2-0000-1000-8000-00805f9b34fb"


def make_advertisement(service_data):
    """Build advertisement data for a synthetic BTHome sensor.

    Args:
        service_data: Service data entries included in the advertisement.

    Returns:
        AdvertisementData matching the given service data.
    """
    return AdvertisementData(
        local_name="Test Sensor",
        manufacturer_data={},
        service_data=service_data,
        service_uuids=list(service_data),
        tx_power=None,
        rssi=-60,
        platform_data=(),
    )


class NormalizeUuidTest(unittest.TestCase):
    def test_expands_16_bit_uuid(self):
        """A 16-bit UUID is expanded to the Bluetooth base UUID."""
        self.assertEqual(
            bthome_scan.normalize_uuid("fcd2"),
            BTHOME_V2_UUID,
        )

    def test_accepts_uppercase_128_bit_uuid(self):
        """A 128-bit UUID is lowercased and kept intact."""
        self.assertEqual(
            bthome_scan.normalize_uuid("0000FCD2-0000-1000-8000-00805F9B34FB"),
            BTHOME_V2_UUID,
        )

    def test_rejects_invalid_uuid(self):
        """An invalid UUID raises ValueError."""
        with self.assertRaises(ValueError):
            bthome_scan.normalize_uuid("not-a-uuid")


class BthomeServiceDataTest(unittest.TestCase):
    def test_keeps_only_bthome_entries(self):
        """Non-BTHome service data entries are filtered out."""
        advertisement = make_advertisement(
            {
                "0000180f-0000-1000-8000-00805f9b34fb": b"\x64",
                "fcd2": b"\x40\x01\x64",
            }
        )
        self.assertEqual(
            bthome_scan.bthome_service_data(advertisement),
            {BTHOME_V2_UUID: b"\x40\x01\x64"},
        )


class ParseAdvertisementTest(unittest.TestCase):
    def setUp(self):
        self.device = BLEDevice("A4:C1:38:00:00:01", "Test Sensor", None)
        self.parser = BTHomeBluetoothDeviceData()

    def parse(self, service_data):
        """Parse advertisement data built from the given service data."""
        advertisement = make_advertisement(service_data)
        return bthome_scan.parse_advertisement(
            self.parser,
            self.device,
            advertisement,
            bthome_scan.bthome_service_data(advertisement),
        )

    def test_decodes_battery_packet(self):
        """A BTHome v2 battery packet is decoded into sensor values."""
        # Version 2, unencrypted, battery object with 100 %.
        record = self.parse({BTHOME_V2_UUID: bytes.fromhex("400164")})
        values = {value["key"]: value for value in record["values"]}

        self.assertEqual(record["address"], "A4:C1:38:00:00:01")
        self.assertIsInstance(record["timestamp"], float)
        self.assertFalse(record["encrypted"])
        self.assertTrue(record["decoded"])
        self.assertEqual(values["battery"]["value"], 100)
        self.assertEqual(values["battery"]["unit"], "%")
        self.assertEqual(values["signal_strength"]["value"], -60)

    def test_marks_encrypted_packet(self):
        """An encrypted packet is flagged and its payload is not decoded."""
        # Version 2, encrypted flag set, no bindkey configured.
        record = self.parse({BTHOME_V2_UUID: bytes.fromhex("410164")})
        keys = {value["key"] for value in record["values"]}

        self.assertTrue(record["encrypted"])
        self.assertFalse(record["decoded"])
        self.assertNotIn("battery", keys)


class BthomeScannerTest(unittest.TestCase):
    def setUp(self):
        self.device = BLEDevice("A4:C1:38:00:00:01", "Test Sensor", None)
        self.records = []
        self.scanner = bthome_scan.BthomeScanner(self.records.append)

    def test_forwards_decoded_bthome_packet(self):
        """A BTHome advertisement is decoded and passed to the callback."""
        advertisement = make_advertisement(
            {BTHOME_V2_UUID: bytes.fromhex("400164")}
        )

        self.scanner.handle_advertisement(self.device, advertisement)

        [record] = self.records
        values = {value["key"]: value for value in record["values"]}
        self.assertEqual(record["address"], "A4:C1:38:00:00:01")
        self.assertEqual(values["battery"]["value"], 100)

    def test_ignores_non_bthome_advertisements(self):
        """Advertisements without BTHome service data are not forwarded."""
        advertisement = make_advertisement(
            {"0000180f-0000-1000-8000-00805f9b34fb": b"\x64"}
        )

        self.scanner.handle_advertisement(self.device, advertisement)

        self.assertEqual(self.records, [])

    def test_ignores_unparseable_packets(self):
        """A parser failure is logged and does not reach the callback."""
        advertisement = make_advertisement(
            {BTHOME_V2_UUID: bytes.fromhex("400164")}
        )
        factory = mock.Mock()
        factory.return_value.update.side_effect = ValueError("bad packet")

        with mock.patch.object(
            bthome_scan, "BTHomeBluetoothDeviceData", factory
        ), self.assertLogs("bthome-scan", "WARNING"):
            self.scanner.handle_advertisement(self.device, advertisement)

        self.assertEqual(self.records, [])

    def test_passes_bindkey_to_parsers(self):
        """The configured bindkey is used for every device parser."""
        advertisement = make_advertisement(
            {BTHOME_V2_UUID: bytes.fromhex("400164")}
        )
        bindkey = bytes(range(16))
        scanner = bthome_scan.BthomeScanner(self.records.append, bindkey)
        factory = mock.Mock()

        with mock.patch.object(bthome_scan, "BTHomeBluetoothDeviceData", factory):
            scanner.handle_advertisement(self.device, advertisement)

        factory.assert_called_once_with(bindkey=bindkey)


if __name__ == "__main__":
    unittest.main()
