"""ml/.venv/Scripts/python -m unittest discover -s ml"""

import unittest

import pandas as pd

from train import delay_pattern
from trips import segments, slot_key

ROUTE = {"id": "r", "stops": [
    {"id": "a", "scheduledTime": "07:00"},
    {"id": "b", "scheduledTime": "07:10"},
    {"id": "c", "scheduledTime": "07:30"},
    {"id": "campus", "scheduledTime": "08:00"},
]}


def times(rows):
    df = pd.DataFrame(rows, columns=["trip_id", "route_id", "date", "direction", "stop_id", "arrived_at"])
    df["arrived_at"] = pd.to_datetime(df["arrived_at"], utc=True).dt.tz_convert("Asia/Kolkata")
    return df


class SlotTest(unittest.TestCase):
    def test_half_hour_slots(self):
        # The same examples as learned_times_test.dart and learned.test.ts.
        self.assertEqual(slot_key(7 * 60 + 29), "07:00")
        self.assertEqual(slot_key(7 * 60 + 30), "07:30")
        self.assertEqual(slot_key(0), "00:00")


class SegmentsTest(unittest.TestCase):
    def test_neighbouring_stops_only_in_route_order_both_ways(self):
        # 07:00 IST is 01:30 UTC. Stop c was not recorded in the morning.
        df = times([
            ("m", "r", "2026-10-12", "toCampus", "a", "2026-10-12T01:30:00Z"),
            ("m", "r", "2026-10-12", "toCampus", "b", "2026-10-12T01:41:00Z"),
            ("m", "r", "2026-10-12", "toCampus", "campus", "2026-10-12T02:35:00Z"),
            ("e", "r", "2026-10-12", "fromCampus", "campus", "2026-10-12T11:00:00Z"),
            ("e", "r", "2026-10-12", "fromCampus", "c", "2026-10-12T11:32:00Z"),
        ])
        segs = segments([ROUTE], df)
        morning = segs[segs.trip_id == "m"]
        self.assertEqual(morning.segment.tolist(), [0])
        self.assertEqual(morning.seconds.tolist(), [660])
        self.assertEqual(morning.scheduled_s.tolist(), [600])
        self.assertEqual(morning.weekday.tolist(), [1])
        self.assertEqual(morning.slot.tolist(), ["07:00"])
        evening = segs[segs.trip_id == "e"]
        self.assertEqual(evening.segment.tolist(), [2])  # campus to c is stretch c-campus
        self.assertEqual(evening.seconds.tolist(), [1920])


class DelayPatternTest(unittest.TestCase):
    def test_median_minutes_late_needs_three_trips(self):
        rows = []
        for day, late in (("2026-10-12", 4), ("2026-10-19", 6), ("2026-10-26", 30), ("2026-10-13", 2)):
            # Campus is due 08:00 IST, which is 02:30 UTC.
            at = pd.Timestamp(f"{day}T02:30:00Z") + pd.Timedelta(minutes=late)
            rows.append((day, "r", day, "toCampus", "campus", at.isoformat()))
        pattern = delay_pattern([ROUTE], times(rows))
        self.assertEqual(pattern, {"r": {"1": {"minutes": 6, "trips": 3}}})


class EvaluateTest(unittest.TestCase):
    def test_every_pair_of_recorded_stops_against_timetable_and_learned(self):
        from evaluate_eta import estimates, learned_segments, summary
        # Monday 12 Oct 2026, from 07:00 IST (01:30 UTC): a 12 min, b 21 min later, campus 51 min.
        df = times([
            ("m", "r", "2026-10-12", "toCampus", "a", "2026-10-12T01:30:00Z"),
            ("m", "r", "2026-10-12", "toCampus", "b", "2026-10-12T01:42:00Z"),
            ("m", "r", "2026-10-12", "toCampus", "c", "2026-10-12T02:03:00Z"),
            ("m", "r", "2026-10-12", "toCampus", "campus", "2026-10-12T02:33:00Z"),
        ])
        learned = {"r": {"slotMinutes": 30, "toCampus": {"1": {"07:00": [720, 1260, 1800]}}}}
        self.assertEqual(learned_segments(learned["r"], "toCampus", 1, 7 * 60 + 50, 4), [720, 1260, 1800])
        self.assertIsNone(learned_segments(learned["r"], "toCampus", 1, 9 * 60, 4))
        est = estimates([ROUTE], df, learned)
        first = est.iloc[0]
        self.assertEqual((first.actual_s, first.timetable_s, first.learned_s), (720, 600, 720))
        self.assertEqual(len(est), 6)
        rows = summary(est)
        # Pairs 12, 21, 30, 33, 51 and 63 min apart: none under 10 min, one from 10 to 20.
        self.assertEqual([r["pairs"] for r in rows], [0, 1, 5])
        self.assertIsNone(rows[0]["timetable"])
        self.assertEqual(rows[1]["timetable"], {"pairs": 1, "meanErrorMin": 2.0, "withinGood": 1.0})
        self.assertEqual(rows[1]["learned"], {"pairs": 1, "meanErrorMin": 0.0, "withinGood": 1.0})


if __name__ == "__main__":
    unittest.main()
