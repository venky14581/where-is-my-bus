"""Trip history in the shape the model learns from.

Both sources write the same two files into a data folder:

- ``routes.json``: ``[{"id", "buses": [busId], "stops": [{"id", "scheduledTime"}]}]``,
  stops in route order (first stop to campus).
- ``stop_times.csv``: ``trip_id, route_id, date, direction, stop_id, arrived_at``,
  one row per recorded stop, ``arrived_at`` in ISO 8601 UTC.

``scripts/export-trips.mjs`` exports recorded trips from Firestore;
``synth_trips.py`` makes synthetic ones until enough real trips exist.
"""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

TIME_ZONE = "Asia/Kolkata"
SLOT_MINUTES = 30


def minutes_of(hhmm: str) -> int | None:
    try:
        h, m = (int(p) for p in hhmm.split(":"))
    except (ValueError, AttributeError):
        return None
    return h * 60 + m if 0 <= h < 24 and 0 <= m < 60 else None


def slot_key(minute_of_day: int) -> str:
    """The half-hour slot a time falls in, as HH:MM. Same as slotKey in the app and functions."""
    start = (minute_of_day // SLOT_MINUTES) * SLOT_MINUTES
    return f"{start // 60:02d}:{start % 60:02d}"


def load(data_dir: Path) -> tuple[list[dict], pd.DataFrame]:
    routes = json.loads((data_dir / "routes.json").read_text(encoding="utf-8"))
    times = pd.read_csv(data_dir / "stop_times.csv")
    times["arrived_at"] = pd.to_datetime(times["arrived_at"], utc=True).dt.tz_convert(TIME_ZONE)
    return routes, times


def segments(routes: list[dict], times: pd.DataFrame) -> pd.DataFrame:
    """One row per stretch the bus drove between two neighbouring stops.

    ``segment`` is the index of the stretch in route order (stop i to i + 1),
    whichever way the bus ran, so morning and evening share an index. Pairs of
    recorded stops that are not neighbours (a stop was not recorded) are left
    out rather than guessed.
    """
    by_id = {r["id"]: r for r in routes}
    rows = []
    for trip_id, trip in times.groupby("trip_id", sort=False):
        route = by_id.get(trip["route_id"].iloc[0])
        if route is None:
            continue
        stop_ids = [s["id"] for s in route["stops"]]
        scheduled = [minutes_of(s.get("scheduledTime", "")) for s in route["stops"]]
        direction = trip["direction"].iloc[0]
        index = {sid: i for i, sid in enumerate(stop_ids)}
        recorded = sorted(
            ((index[r.stop_id], r.arrived_at) for r in trip.itertuples() if r.stop_id in index),
            reverse=direction == "fromCampus",
        )
        for (a, at_a), (b, at_b) in zip(recorded, recorded[1:]):
            if abs(a - b) != 1:
                continue
            seconds = (at_b - at_a).total_seconds()
            if seconds <= 0:
                continue
            segment = min(a, b)
            gap = scheduled[segment + 1], scheduled[segment]
            rows.append({
                "trip_id": trip_id,
                "route_id": route["id"],
                "direction": direction,
                "segment": segment,
                "date": at_a.strftime("%Y-%m-%d"),
                "weekday": at_a.isoweekday(),
                "slot": slot_key(at_a.hour * 60 + at_a.minute),
                "minute_of_day": at_a.hour * 60 + at_a.minute,
                "scheduled_s": abs(gap[0] - gap[1]) * 60 if None not in gap else float("nan"),
                "seconds": seconds,
            })
    return pd.DataFrame(rows)


def campus_delays(routes: list[dict], times: pd.DataFrame) -> pd.DataFrame:
    """Minutes late at campus for each morning trip, from the timetable."""
    rows = []
    for route in routes:
        campus = route["stops"][-1]
        due = minutes_of(campus.get("scheduledTime", ""))
        if due is None:
            continue
        arrived = times[(times["route_id"] == route["id"]) & (times["direction"] == "toCampus") & (times["stop_id"] == campus["id"])]
        for r in arrived.itertuples():
            at = r.arrived_at
            rows.append({
                "route_id": route["id"],
                "weekday": at.isoweekday(),
                "minutes_late": (at.hour * 60 + at.minute + at.second / 60) - due,
            })
    return pd.DataFrame(rows, columns=["route_id", "weekday", "minutes_late"])
