# Module 11: Smart features

Status: **built and tested on the emulators and the web app, 11 Oct 2026,
with synthetic trip history.** As with earlier modules, `SPEC.md` was not
available, so the scope and Done-when test below were written for this
module from the features document ("Features: smart features"). Confirm
them. The model must be retrained on recorded trips (at least two weeks)
before anyone relies on its numbers.

## What was built

- **Learned arrival time.** `ml/train.py` learns how long each stretch
  between two stops takes, by route, direction, weekday and time of day
  (scikit-learn gradient boosting on stretch times from past trips). It
  checks itself against the most recent days, which it does not train on,
  and writes the expected seconds for every stretch by weekday and
  half-hour slot to `ml/out/segment_times.json`. The seed (or
  `npm run import-ml`) loads it into `segmentTimes/{routeId}`. The app
  spreads those times along the road the way it spread the timetable; with
  nothing learned for the weekday and time (within an hour), it falls back
  to the timetable as before.
- **Trip history.** `npm run export-trips` writes ended trips and their stop
  times to `ml/data/` (bus times only, nothing about students). Until there
  are enough, `ml/synth_trips.py` makes 8 weeks of synthetic trips from the
  timetable, with slower Mondays and Fridays, quicker Saturdays, a morning
  and evening rush, and rainy days. Everything made from them is labelled
  `synthetic`.
- **Rain and traffic adjustment.** Each recorded stop time compares the
  stretch just driven with what was expected and adds the ratio to
  `conditions/{date}` (`noteTraffic`, once per stop time). Once three
  stretches are in, every estimate that day is stretched by their average,
  between 1 and 1.5: a slow morning adds time; a quick one changes
  nothing. One odd stretch counts as at most 3 times slow.
- **Leave-home reminder.** A student sets their walk from home to the stop
  (Notifications settings). The home screen shows "Leave home by 7:21 AM",
  or "Leave now to catch it", from the arrival estimate less the walk and
  two minutes. The server sends one "Time to leave" push per trip
  (`remindToLeave`, at trip start and each stop): at the last stop from
  which the reminder is still in time. Mornings only; it can be switched
  off. Only a number of minutes is stored, never a location.
- **Delay pattern.** The usual minutes late at campus by weekday (median,
  from at least three trips) comes with the learned times. The home screen
  shows today's ("Usually about 6 min late on Fridays"); the full route
  shows the week.
- **Crowding level.** "Seats available", "Few seats left" or "Standing
  only" for the running trip, from its pass holders less those not riding,
  seats held by other routes' riders and guest bookings.
- **Not riding today** (left out of Module 10). On Evening seats, a pass
  holder can mark their route's evening bus "Not riding this evening",
  which frees their seat for booking (`setNotRiding`). The seat count is
  now `capacity − (passHolders − notRiding) − altHeld − seatsBooked`, in
  the functions and the app alike. The choice locks when booking closes,
  and cannot be taken back once the freed seat has been sold.

## Done when

`npm run test:e2e` (`tests/e2e/m11-smart.test.js`), the app's
`test/smart_test.dart`, `functions/src/learned.test.ts` and
`ml/test_trips.py`, plus a run of the web app on the emulators with a
simulated bus:

| # | Check | Result |
| --- | --- | --- |
| 1 | The model beats the timetable on days it was not trained on. | Pass (synthetic: 94 s mean error per stretch against 149 s for the timetable, 115 s for each stretch's average) |
| 2 | The seed loads learned times for every route; college accounts read them; nobody writes them from an app. | Pass (e2e, rules tests) |
| 3 | The app and the functions pick the same learned times for the same day and time, and fall back to the timetable when nothing fits. | Pass (shared example in Dart and TypeScript) |
| 4 | Learned times replace the timetable in the estimate, and a slow morning stretches it. | Pass (widget test: 15 → 30 → 36 min) |
| 5 | Stretches driven 1.5 times slower than expected give that day a factor of 1.5. | Pass (e2e) |
| 6 | The home screen shows when to leave, or to leave now; nothing without a walk. | Pass (widget tests; live: "Leave home by 4:21 AM" for a bus due 4:33 with a 10 min walk) |
| 7 | The leave-home push reaches a rider who must leave now at trip start, a rider further on when the stop before theirs is reached, each once, and nobody who switched it off or gave no walk. | Pass (e2e; live: pushed at Kuniyamuthur for Madukkarai) |
| 8 | Today's usual delay and the crowding level show on the home screen. | Pass (widget test; live: "Seats available") |
| 9 | Not riding frees the seat once; it can be sold; then it cannot be taken back; after closing it is locked; only for your own route with a pass. | Pass (e2e, widget test) |
| 10 | Tests pass. | Pass: 121 app, 39 function, 65 rules, 9 dashboard, 56 e2e, 3 Python tests |
| 11 | **Retrained on at least two weeks of recorded trips**, with the error checked again. | **Not run: no recorded trips yet** |

## Using real trips

```bash
npm run export-trips -- --project <project-id> --out ../ml/data
```

```bash
ml/.venv/Scripts/python ml/train.py
```

Then load `ml/out/segment_times.json`: `npm run import-ml` on the
emulators; for a real project, run `importLearnedTimes` from
`scripts/learned-times.mjs` with that project's Admin credentials. Retrain
every few weeks, and after the timetable or a route changes (learned times
that no longer fit a route's stops are ignored).

## Known gaps

- **Check 11.** Synthetic trips only show that the pipeline works. The
  delays they contain were made up.
- **Weekdays without trips** (Sundays) and times far from any recorded
  trip have no learned times; the timetable is used.
- **Not riding** is for evening buses, which exist ahead of time. Morning
  trips are created when the driver starts them, so a day scholar cannot
  yet say in advance that they will not ride in the morning.
- **A pass holder who marked Not riding and turns up anyway** is still
  boarded (pass holders keep priority); the bus may then be one over.
- **The leave-home reminder can be up to one stretch early**, never late,
  and uses a walk the student types in, not their location.
- **Simulated drives** on the emulators run 5 times fast, so they record
  `conditions` at the 0.5 floor; this never slows estimates, which only
  ever grow.
- No Jupyter notebook yet; `ml/train.py` prints its evaluation instead.
