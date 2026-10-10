"""Learned arrival time and delay pattern (Module 11).

Learns how long each stretch between two stops takes, from past trips on the
route, by weekday and half-hour of the day, and checks it against the
timetable on the most recent days, which it does not train on. Then writes:

- for every route, direction, weekday and half-hour slot, the expected
  seconds for each stretch in route order; the app and the functions look
  these up instead of spreading the timetable evenly (see
  ``learnedSegments`` in app/lib/features/eta/domain/learned_times.dart
  and functions/src/learned.ts);
- for every route, the usual minutes late at campus by weekday.

    ml/.venv/Scripts/python ml/train.py           (reads ml/data/, writes ml/out/)
    npm run import-ml                              (loads ml/out/ into the emulators)
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor

from trips import SLOT_MINUTES, campus_delays, load, minutes_of, segments, slot_key

ROOT = Path(__file__).resolve().parent.parent
FEATURES = ["route_id", "direction", "segment", "weekday", "minute_of_day", "scheduled_s"]
CATEGORICAL = ["route_id", "direction"]
# A weekday's usual delay is shown only once there are this many trips.
MIN_TRIPS_FOR_PATTERN = 3


def features(df: pd.DataFrame, categories: dict[str, list[str]]) -> pd.DataFrame:
    x = df[FEATURES].copy()
    for column in CATEGORICAL:
        x[column] = pd.Categorical(x[column], categories=categories[column])
    return x


def fit(train: pd.DataFrame, categories: dict[str, list[str]]) -> HistGradientBoostingRegressor:
    model = HistGradientBoostingRegressor(
        categorical_features="from_dtype", max_iter=300, learning_rate=0.08, random_state=0,
    )
    model.fit(features(train, categories), train["seconds"])
    return model


def evaluate(segs: pd.DataFrame, categories: dict[str, list[str]], test_fraction: float = 0.2) -> dict:
    """Trains on the earlier days and scores the most recent ones."""
    dates = sorted(segs["date"].unique())
    cut = dates[int(len(dates) * (1 - test_fraction))]
    train, test = segs[segs["date"] < cut], segs[segs["date"] >= cut]
    model = fit(train, categories)
    predicted = model.predict(features(test, categories))
    mean = train.groupby(["route_id", "direction", "segment"])["seconds"].mean()
    by_segment = test.apply(lambda r: mean.get((r.route_id, r.direction, r.segment), r.scheduled_s), axis=1)
    mae = lambda guess: float(np.mean(np.abs(test["seconds"].to_numpy() - np.asarray(guess, dtype=float))))
    return {
        "trainDays": int(sum(1 for d in dates if d < cut)),
        "testDays": int(sum(1 for d in dates if d >= cut)),
        "testStretches": int(len(test)),
        "maeSeconds": {
            "model": round(mae(predicted), 1),
            "segmentAverage": round(mae(by_segment), 1),
            "timetable": round(mae(test["scheduled_s"].fillna(by_segment)), 1),
        },
    }


def table(model, routes: list[dict], segs: pd.DataFrame, categories: dict[str, list[str]]) -> dict:
    """Expected seconds per stretch, for every slot the route runs in."""
    out: dict = {}
    for route in routes:
        stops = route["stops"]
        scheduled = [minutes_of(s.get("scheduledTime", "")) for s in stops]
        gaps = [abs(scheduled[i + 1] - scheduled[i]) * 60 if None not in (scheduled[i], scheduled[i + 1]) else np.nan
                for i in range(len(stops) - 1)]
        entry: dict = {}
        for direction in ("toCampus", "fromCampus"):
            seen = segs[(segs["route_id"] == route["id"]) & (segs["direction"] == direction)]
            if seen.empty:
                continue
            slots = sorted({m // SLOT_MINUTES * SLOT_MINUTES + d * SLOT_MINUTES for m in seen["minute_of_day"] for d in (-1, 0, 1)})
            weekdays = sorted(seen["weekday"].unique())
            grid = pd.DataFrame([
                {"route_id": route["id"], "direction": direction, "segment": i, "weekday": int(w),
                 "minute_of_day": slot + SLOT_MINUTES // 2, "scheduled_s": gaps[i], "slot": slot_key(slot)}
                for w in weekdays for slot in slots for i in range(len(gaps))
            ])
            grid["seconds"] = np.maximum(30, model.predict(features(grid, categories)).round())
            entry[direction] = {
                str(w): {slot: [int(s) for s in g.sort_values("segment")["seconds"]] for slot, g in by_w.groupby("slot")}
                for w, by_w in grid.groupby("weekday")
            }
        out[route["id"]] = entry
    return out


def delay_pattern(routes: list[dict], times: pd.DataFrame) -> dict:
    delays = campus_delays(routes, times)
    pattern: dict = {}
    for (route_id, weekday), g in delays.groupby(["route_id", "weekday"]):
        if len(g) >= MIN_TRIPS_FOR_PATTERN:
            pattern.setdefault(route_id, {})[str(int(weekday))] = {
                "minutes": int(round(g["minutes_late"].median())),
                "trips": int(len(g)),
            }
    return pattern


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=ROOT / "ml" / "data")
    parser.add_argument("--out", type=Path, default=ROOT / "ml" / "out" / "segment_times.json")
    args = parser.parse_args()

    routes, times = load(args.data)
    segs = segments(routes, times)
    if segs.empty:
        raise SystemExit(f"No usable trips in {args.data}.")
    categories = {c: sorted(segs[c].unique()) for c in CATEGORICAL}
    source_file = args.data / "SOURCE"
    source = source_file.read_text(encoding="utf-8").strip() if source_file.exists() else "recorded"

    evaluation = evaluate(segs, categories)
    model = fit(segs, categories)
    learned = table(model, routes, segs, categories)
    pattern = delay_pattern(routes, times)

    result = {
        "source": source,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "trips": int(times["trip_id"].nunique()),
        "from": str(min(segs["date"])),
        "to": str(max(segs["date"])),
        "slotMinutes": SLOT_MINUTES,
        "evaluation": evaluation,
        "routes": {
            r["id"]: {**learned.get(r["id"], {}), "delayByWeekday": pattern.get(r["id"], {})} for r in routes
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1), encoding="utf-8")
    mae = evaluation["maeSeconds"]
    print(f"{result['trips']} {source} trips, {result['from']} to {result['to']}")
    print(f"Error per stretch on the last {evaluation['testDays']} days (mean, seconds): "
          f"model {mae['model']}, segment average {mae['segmentAverage']}, timetable {mae['timetable']}")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
