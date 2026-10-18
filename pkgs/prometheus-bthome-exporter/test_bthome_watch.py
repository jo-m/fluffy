"""Tests for bthome_watch's device tracking and rendering."""

import unittest

import bthome_watch


def make_record(
    *,
    address="AA:BB:CC:DD:EE:01",
    name="Test Sensor",
    title="ATC 0001",
    rssi=-60,
    timestamp=1000.0,
):
    """Build a scanner record with the fields used by the tracker."""
    return {
        "address": address,
        "name": name,
        "title": title,
        "rssi": rssi,
        "timestamp": timestamp,
    }


class DeviceTrackerTest(unittest.TestCase):
    def test_tracks_device_from_first_record(self):
        """A first packet creates a device entry."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(make_record())

        [device] = tracker.snapshot()
        self.assertEqual(device.address, "AA:BB:CC:DD:EE:01")
        self.assertEqual(device.name, "ATC 0001")
        self.assertEqual(device.rssi, -60)
        self.assertEqual(device.last_seen, 1000.0)

    def test_updates_signal_and_last_seen(self):
        """Later packets refresh RSSI and the last-seen time."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(make_record())
        tracker.update(make_record(rssi=-70, timestamp=1010.0))

        [device] = tracker.snapshot()
        self.assertEqual(device.rssi, -70)
        self.assertEqual(device.last_seen, 1010.0)

    def test_prefers_parser_title(self):
        """The parser title is shown instead of the advertised name."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(make_record(name="ATC_0001", title="ATC 0001"))

        [device] = tracker.snapshot()
        self.assertEqual(device.name, "ATC 0001")

    def test_falls_back_to_address(self):
        """A device without any name is shown by address."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(make_record(name=None, title=None))

        [device] = tracker.snapshot()
        self.assertEqual(device.name, "AA:BB:CC:DD:EE:01")

    def test_snapshot_returns_copies(self):
        """Mutating a snapshot does not change the tracked state."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(make_record())
        tracker.snapshot()[0].rssi = -10

        [device] = tracker.snapshot()
        self.assertEqual(device.rssi, -60)


class FormatBarTest(unittest.TestCase):
    def test_bar_scales_with_rssi(self):
        """Stronger signals produce longer bars."""
        self.assertEqual(bthome_watch.format_bar(-100), "")
        self.assertEqual(bthome_watch.format_bar(-50), "#" * 10)
        self.assertEqual(bthome_watch.format_bar(-43), "#" * 11)
        self.assertEqual(bthome_watch.format_bar(0), "#" * 20)

    def test_bar_clamps_out_of_range_rssi(self):
        """Values outside the supported range clamp to the bar bounds."""
        self.assertEqual(bthome_watch.format_bar(-120), "")
        self.assertEqual(bthome_watch.format_bar(10), "#" * 20)


class FormatAgeTest(unittest.TestCase):
    def test_formats_seconds(self):
        """The age is rendered in whole seconds."""
        self.assertEqual(
            bthome_watch.format_age(now=1000.0, last_seen=970.0),
            "last seen 30 s ago",
        )

    def test_clamps_future_timestamps(self):
        """A last-seen time in the future renders as zero seconds."""
        self.assertEqual(
            bthome_watch.format_age(now=1000.0, last_seen=1010.0),
            "last seen 0 s ago",
        )

    def test_handles_missing_timestamp(self):
        """A missing timestamp is rendered as unknown."""
        self.assertEqual(
            bthome_watch.format_age(now=1000.0, last_seen=None),
            "last seen ?",
        )


class FormatReportTest(unittest.TestCase):
    def make_tracker(self):
        """Create a tracker with three devices seen at known times."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(
            make_record(
                address="AA:BB:CC:DD:EE:01",
                title="Zeta",
                rssi=-80,
                timestamp=1000.0,
            )
        )
        tracker.update(
            make_record(
                address="AA:BB:CC:DD:EE:02",
                title="alpha",
                rssi=-50,
                timestamp=970.0,
            )
        )
        tracker.update(
            make_record(
                address="AA:BB:CC:DD:EE:03",
                title="Beta",
                rssi=-95,
                timestamp=990.0,
            )
        )
        return tracker

    def test_sorts_devices_by_name_case_insensitively(self):
        """The table order is stable and independent of advertisement order."""
        lines = bthome_watch.render(
            self.make_tracker(), now=1000.0
        ).splitlines()[1:]

        self.assertTrue(lines[0].startswith("alpha"))
        self.assertTrue(lines[1].startswith("Beta"))
        self.assertTrue(lines[2].startswith("Zeta"))

    def test_includes_address_rssi_bar_and_age(self):
        """Each row shows address, RSSI, a bar and the last-seen age."""
        report = bthome_watch.render(self.make_tracker(), now=1000.0)
        zeta = next(line for line in report.splitlines() if "Zeta" in line)

        self.assertIn("AA:BB:CC:DD:EE:01", zeta)
        self.assertIn("-80 dBm", zeta)
        self.assertIn("####", zeta)
        self.assertIn("last seen 0 s ago", zeta)

    def test_includes_address_header(self):
        """The table header labels the address column."""
        report = bthome_watch.render(self.make_tracker(), now=1000.0)

        self.assertIn("Address", report.splitlines()[0])

    def test_skips_devices_without_finite_rssi(self):
        """Devices whose RSSI is missing or NaN are not listed."""
        tracker = bthome_watch.DeviceTracker()
        tracker.update(
            make_record(
                address="AA:BB:CC:DD:EE:01", title="NoRssi", rssi=None
            )
        )
        tracker.update(
            make_record(
                address="AA:BB:CC:DD:EE:02",
                title="NaN",
                rssi=float("nan"),
            )
        )

        self.assertEqual(
            bthome_watch.render(tracker, now=1000.0),
            "No BTHome devices seen yet.",
        )

    def test_reports_empty_tracker(self):
        """An empty tracker produces a clear message."""
        self.assertEqual(
            bthome_watch.format_report([], now=1000.0),
            "No BTHome devices seen yet.",
        )


if __name__ == "__main__":
    unittest.main()
