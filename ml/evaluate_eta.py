"""How close arrival times are to the real thing (Module 13, pilot).

For every recorded trip, and every pair of stops on it (the bus at one stop,
a student waiting at a later one), compares the real time between them with
what the app would have said: from the timetable, and from the learned
times. Reported by how far ahead the estimate was made, since an estimate
for a stop an hour away matters less than one for the next stop.

    ml/.venv/Scripts/python ml/evaluate_eta.py                       (ml/data/, ml/out/segment_times.json)
    ml/.venv/Scripts/python ml/evaluate_eta.py --data <dir> --learned <file>

For the pilot, train on the first days and evaluate on the later ones:
export each period into its own folder.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from trips import load, minutes_of

ROOT = Path(__file__).resolve().parent.parent
#: Within this many minutes counts as right for a student deciding when to leave.
GOOD_MINUTES = 2
#: Same as learnedSegments in the app and functions.
MAX_SLOT_DISTANCE = 60
BUCKETS = [(0, 10, "up to 10 min ahead"), (10, 20, "10 to 20 min ahead"), (20, 24 * 60, "over 20 min ahead")]


def learned_segments(learned: dict | None, direction: str, weekday: int, minute: int, stop_count: int) -> list[int] | None:
    """The learned seconds per stretch for a trip at this weekday and time, as the app picks them."""
    by_day = ((learned or {}).get(direction) or {}).get(str(weekday))
    if not by_day:
        return None
    slot_minutes = (learned or {}).get("slotMinutes", 30)
    target = minute // slot_minutes * slot_minutes
    best = min(by_day, key=lambda k: (abs(minutes_of(k) - target), k))
    if abs(minutes_of(best) - target) > MAX_SLOT_DISTANCE or len(by_day[best]) != stop_count - 1:
        return None
    return by_day[best]


def estimates(routes: list[dict], times: pd.DataFrame, learned_routes: dict) -> pd.DataFrame:
    """One row per (trip, from stop, to stop): actual, timetable and learned seconds."""
    by_id = {r["id"]: r for r in routes}
    rows = []
    for trip_id, trip in times.groupby("trip_id", sort=False):
        route = by_id.get(trip["route_id"].iloc[0])
        if route is None:
            continue
        direction = trip["direction"].iloc[0]
        ids = [s["id"] for s in route["stops"]]
        scheduled = [minutes_of(s.get("scheduledTime", "")) for s in route["stops"]]
        index = {sid: i for i, sid in enumerate(ids)}
        seen = sorted(((index[r.stop_id], r.arrived_at) for r in trip.itertuples() if r.stop_id in index),
                      key=lambda x: x[1])
        for a, (i, at_i) in enumerate(seen):
            segs = learned_segments(learned_routes.get(route["id"]), direction, at_i.isoweekday(),
                                    at_i.hour * 60 + at_i.minute, len(ids))
            for j, at_j in seen[a + 1:]:
                lo, hi = min(i, j), max(i, j)
                actual = (at_j - at_i).total_seconds()
                gaps = [scheduled[k + 1] - scheduled[k] if None not in (scheduled[k], scheduled[k + 1]) else None
                        for k in range(lo, hi)]
                rows.append({
                    "trip_id": trip_id,
                    "route_id": route["id"],
                    "actual_s": actual,
                    "timetable_s": sum(g * 60 for g in gaps) if None not in gaps else None,
                    "learned_s": sum(segs[lo:hi]) if segs else None,
                })
    return pd.DataFrame(rows, columns=["trip_id", "route_id", "actual_s", "timetable_s", "learned_s"])


def summary(est: pd.DataFrame) -> list[dict]:
    """Mean error (minutes) and share within GOOD_MINUTES, by how far ahead, for each method."""
    out = []
    for lo, hi, label in BUCKETS:
        part = est[(est["actual_s"] >= lo * 60) & (est["actual_s"] < hi * 60)]
        row = {"ahead": label, "pairs": int(len(part))}
        for method in ("timetable", "learned"):
            have = part[part[f"{method}_s"].notna()]
            err = (have[f"{method}_s"] - have["actual_s"]).abs() / 60
            row[method] = None if have.empty else {
                "pairs": int(len(have)),
                "meanErrorMin": round(float(err.mean()), 1),
                "withinGood": round(float((err <= GOOD_MINUTES).mean()), 2),
            }
        out.append(row)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=ROOT / "ml" / "data")
    parser.add_argument("--learned", type=Path, default=ROOT / "ml" / "out" / "segment_times.json")
    args = parser.parse_args()

    routes, times = load(args.data)
    learned = json.loads(args.learned.read_text(encoding="utf-8")) if args.learned.exists() else {"routes": {}}
    est = estimates(routes, times, learned.get("routes", {}))
    print(f"{times['trip_id'].nunique()} trips, {len(est)} stop pairs. Error in minutes; "
          f"'within {GOOD_MINUTES}' is the share of estimates no more than {GOOD_MINUTES} min out.")
    if learned.get("source") == "synthetic":
        print("The learned times are from synthetic trips.")
    for row in summary(est):
        cells = []
        for method in ("timetable", "learned"):
            r = row[method]
            cells.append(f"{method}: " + ("no estimate" if r is None else f"{r['meanErrorMin']} min, {round(r['withinGood'] * 100)}% within {GOOD_MINUTES}"))
        print(f"  {row['ahead']:>20} ({row['pairs']} pairs)  " + " | ".join(cells))


if __name__ == "__main__":
    main()
