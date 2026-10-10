"""Synthetic trip history, until two weeks of real trips are recorded.

Builds trips for every route in data/base-data.json from its timetable, with
the patterns a real route is likely to show, so the pipeline can be built
and tested now:

- Mondays and Fridays slower, Saturdays quicker;
- the morning and evening rush slower than the rest of the trip;
- about one day in seven with rain, when every bus is slower;
- random variation on every stretch, and the odd stop not recorded.

    ml/.venv/Scripts/python ml/synth_trips.py            (writes ml/data/)

The output is labelled synthetic wherever it ends up. Replace it with
recorded trips (scripts/export-trips.mjs) as soon as there are enough.
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import numpy as np

from trips import minutes_of

ROOT = Path(__file__).resolve().parent.parent
IST = timezone(timedelta(hours=5, minutes=30))

WEEKDAY_FACTOR = {1: 1.10, 2: 1.0, 3: 0.98, 4: 1.02, 5: 1.12, 6: 0.90}
RUSH = {"toCampus": (7 * 60 + 15, 8 * 60), "fromCampus": (17 * 60, 17 * 60 + 45)}
RUSH_FACTOR = 1.15
RAIN_FACTOR = 1.3
EVENING_DEPARTS = 16 * 60 + 30


def base_routes() -> list[dict]:
    data = json.loads((ROOT / "data" / "base-data.json").read_text(encoding="utf-8"))
    buses = {}
    for bus in data["buses"]:
        buses.setdefault(bus["routeId"], []).append(bus["id"])
    return [
        {
            "id": r["id"],
            "buses": buses.get(r["id"], []),
            "stops": [{"id": s["id"], "scheduledTime": s["scheduledTime"]} for s in r["stops"]],
        }
        for r in data["routes"]
    ]


def drive(rng, route: dict, day: date, direction: str, rainy: bool) -> list[tuple[str, datetime]]:
    """Arrival times at each stop of one trip, in travel order."""
    stops = route["stops"]
    scheduled = [minutes_of(s["scheduledTime"]) for s in stops]
    gaps = [(scheduled[i + 1] - scheduled[i]) * 60 for i in range(len(stops) - 1)]
    order = list(range(len(stops)))
    if direction == "toCampus":
        start_minute = scheduled[0] + rng.normal(0, 2)
    else:
        order.reverse()
        start_minute = EVENING_DEPARTS + rng.normal(0, 3)
    at = datetime(day.year, day.month, day.day, tzinfo=IST) + timedelta(minutes=start_minute)
    rush_from, rush_to = RUSH[direction]
    arrivals = [(stops[order[0]]["id"], at)]
    for a, b in zip(order, order[1:]):
        seconds = gaps[min(a, b)] * WEEKDAY_FACTOR[day.isoweekday()]
        minute = at.hour * 60 + at.minute
        if rush_from <= minute < rush_to:
            seconds *= RUSH_FACTOR
        if rainy:
            seconds *= RAIN_FACTOR
        seconds *= rng.lognormal(0, 0.07)
        at = at + timedelta(seconds=seconds)
        arrivals.append((stops[b]["id"], at))
    return arrivals


def generate(weeks: int, end: date, seed: int) -> tuple[list[dict], list[dict]]:
    rng = np.random.default_rng(seed)
    routes = base_routes()
    rows = []
    for offset in range(weeks * 7, 0, -1):
        day = end - timedelta(days=offset - 1)
        if day.isoweekday() == 7:
            continue  # no college buses on Sundays
        rainy = rng.random() < 0.15
        for route in routes:
            for bus in route["buses"]:
                for direction in ("toCampus", "fromCampus"):
                    trip_id = f"{day.isoformat()}_{bus}_{direction}"
                    for stop_id, at in drive(rng, route, day, direction, rainy):
                        if rng.random() < 0.05:
                            continue  # the phone missed this stop
                        rows.append({
                            "trip_id": trip_id,
                            "route_id": route["id"],
                            "date": day.isoformat(),
                            "direction": direction,
                            "stop_id": stop_id,
                            "arrived_at": at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
                        })
    return routes, rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--weeks", type=int, default=8)
    # Fixed by default so the committed model output can be rebuilt exactly.
    parser.add_argument("--end", type=date.fromisoformat, default=date(2026, 10, 10))
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--out", type=Path, default=ROOT / "ml" / "data")
    args = parser.parse_args()

    routes, rows = generate(args.weeks, args.end, args.seed)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "routes.json").write_text(json.dumps(routes, indent=2), encoding="utf-8")
    with (args.out / "stop_times.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    (args.out / "SOURCE").write_text("synthetic\n", encoding="utf-8")
    trips = len({r["trip_id"] for r in rows})
    print(f"Wrote {trips} synthetic trips ({len(rows)} stop times) to {args.out}")


if __name__ == "__main__":
    main()
