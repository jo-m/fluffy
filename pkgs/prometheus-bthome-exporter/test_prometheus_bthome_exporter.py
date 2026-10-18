"""Tests for prometheus_bthome_exporter."""

import tempfile
import unittest
from pathlib import Path

from prometheus_client import CollectorRegistry, generate_latest
from prometheus_client.parser import text_string_to_metric_families

import prometheus_bthome_exporter


def make_record(
    *,
    values=None,
    binary_values=None,
    events=None,
    rssi=-60,
    timestamp=123.0,
    address="A4:C1:38:00:00:01",
    name="Test Sensor",
    title="ATC 0001",
):
    """Build a packet record shaped like build_record's output.

    Args:
        values: Sensor value entries.
        binary_values: Binary sensor entries.
        events: Event entries.
        rssi: Advertisement RSSI.
        timestamp: Unix timestamp of the advertisement.
        address: Bluetooth address.
        name: Advertised device name.
        title: Parser-assigned device title.

    Returns:
        A record suitable for DeviceRegistry.update.
    """
    return {
        "time": "2026-10-18T21:00:00.000+00:00",
        "timestamp": timestamp,
        "address": address,
        "name": name,
        "title": title,
        "rssi": rssi,
        "encrypted": False,
        "decoded": True,
        "service_data": {},
        "values": values or [],
        "binary_values": binary_values or [],
        "events": events or [],
    }


def sensor(key, value, unit=None):
    """Build a sensor value entry."""
    return {
        "key": key,
        "name": key,
        "value": value,
        "unit": unit,
        "device_class": None,
    }


def binary_sensor(key, value):
    """Build a binary sensor entry."""
    return {
        "key": key,
        "name": key,
        "value": value,
        "device_class": None,
    }


def event(key, event_type, properties=None):
    """Build an event entry."""
    return {
        "key": key,
        "name": key,
        "type": event_type,
        "properties": properties or {},
    }


def collect_samples(registry):
    """Collect all metric samples from a collector registry.

    Args:
        registry: Device registry to expose.

    Returns:
        A list of prometheus_client Sample objects.
    """
    output = generate_latest(collector_registry(registry)).decode()
    return [
        sample
        for family in text_string_to_metric_families(output)
        for sample in family.samples
    ]


def collector_registry(registry):
    """Wrap a DeviceRegistry in a Prometheus collector registry.

    Args:
        registry: Device registry to expose.

    Returns:
        A CollectorRegistry containing only the BTHome collector.
    """
    prometheus_registry = CollectorRegistry()
    prometheus_registry.register(
        prometheus_bthome_exporter.BthomeCollector(registry)
    )
    return prometheus_registry


class DeviceRegistryTest(unittest.TestCase):
    def test_stores_latest_device_state(self):
        """A packet record becomes a device state with all metric fields."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        registry.update(
            make_record(
                values=[sensor("battery", 100, "%")],
                binary_values=[binary_sensor("window", True)],
                events=[event("button", "press", {"press_type": "short"})],
            )
        )

        [device] = registry.snapshot()
        self.assertEqual(device.address, "A4:C1:38:00:00:01")
        self.assertEqual(device.name, "ATC 0001")
        self.assertEqual(device.rssi, -60)
        self.assertEqual(device.timestamp, 123.0)
        self.assertEqual(device.values["battery"], (100.0, "%"))
        self.assertEqual(device.binary_values["window"], 1.0)
        self.assertEqual(device.events[("button", "press")], 1)

    def test_merges_values_from_successive_packets(self):
        """Values absent from a later packet are retained."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        registry.update(make_record(values=[sensor("battery", 100, "%")]))
        registry.update(make_record(values=[sensor("temperature", 21.5, "C")]))

        [device] = registry.snapshot()
        self.assertEqual(device.values["battery"], (100.0, "%"))
        self.assertEqual(device.values["temperature"], (21.5, "C"))

    def test_increments_event_counters(self):
        """Repeated events accumulate in the counter."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        record = make_record(events=[event("button", "press")])
        registry.update(record)
        registry.update(record)

        [device] = registry.snapshot()
        self.assertEqual(device.events[("button", "press")], 2)

    def test_skips_non_numeric_sensor_values(self):
        """Non-numeric entity values are not exported."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        registry.update(
            make_record(
                values=[
                    sensor("mode", "auto"),
                    sensor("enabled", True),
                    sensor("battery", 100, "%"),
                ]
            )
        )

        [device] = registry.snapshot()
        self.assertEqual(list(device.values), ["battery"])

    def test_reports_new_devices(self):
        """Update returns True only the first time an address is seen."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        record = make_record()

        self.assertTrue(registry.update(record))
        self.assertFalse(registry.update(record))


class BthomeCollectorTest(unittest.TestCase):
    def test_exposes_device_metrics(self):
        """Collector exposes sensor, binary, event, RSSI and timestamp metrics."""
        registry = prometheus_bthome_exporter.DeviceRegistry()
        record = make_record(
            values=[sensor("battery", 100, "%")],
            binary_values=[binary_sensor("window", True)],
            events=[event("button", "press", {"press_type": "short"})],
        )
        registry.update(record)
        registry.update(record)

        samples = collect_samples(registry)
        output = generate_latest(collector_registry(registry)).decode()

        def sample(metric_name, **labels):
            return next(
                sample
                for sample in samples
                if sample.name == metric_name and sample.labels == labels
            )

        labels = {"address": record["address"], "name": "ATC 0001"}
        self.assertEqual(
            sample(
                "bthome_sensor_value",
                **labels,
                sensor="battery",
                unit="%",
            ).value,
            100.0,
        )
        self.assertEqual(
            sample("bthome_binary_sensor", **labels, sensor="window").value,
            1.0,
        )
        self.assertEqual(
            sample(
                "bthome_events_total",
                **labels,
                event="button",
                type="press",
            ).value,
            2.0,
        )
        self.assertEqual(sample("bthome_rssi_dbm", **labels).value, -60.0)
        self.assertEqual(
            sample("bthome_last_seen_timestamp_seconds", **labels).value,
            123.0,
        )
        self.assertNotIn("press_type", output)

    def test_exposes_no_device_metrics_for_empty_registry(self):
        """An empty registry still yields valid metric output."""
        output = generate_latest(
            collector_registry(prometheus_bthome_exporter.DeviceRegistry())
        ).decode()

        self.assertIn("bthome_sensor_value", output)
        self.assertNotIn("bthome_sensor_value{", output)


class BindkeyTest(unittest.TestCase):
    def test_decodes_hex_bindkey(self):
        """A 32-character hex string decodes to 16 bytes."""
        bindkey = "00112233445566778899aabbccddeeff"

        self.assertEqual(
            prometheus_bthome_exporter.decode_bindkey(bindkey),
            bytes.fromhex(bindkey),
        )

    def test_rejects_invalid_bindkey(self):
        """Non-hex and short strings are rejected."""
        for value in ["not-hex", "0011"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                prometheus_bthome_exporter.decode_bindkey(value)

    def test_reads_bindkey_file(self):
        """A bindkey file may end with a newline."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "bindkey")
            path.write_text("00" * 16 + "\n", encoding="ascii")

            self.assertEqual(
                prometheus_bthome_exporter.read_bindkey_file(str(path)),
                bytes(16),
            )

    def test_rejects_missing_bindkey_file(self):
        """A missing bindkey file raises OSError."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "missing")
            with self.assertRaises(OSError):
                prometheus_bthome_exporter.read_bindkey_file(str(path))


if __name__ == "__main__":
    unittest.main()
