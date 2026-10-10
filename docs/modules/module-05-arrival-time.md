# Module 5: Arrival time

Status: **done**, 10 Oct 2026. Tested on Flutter web against the emulators
with a simulated bus. As with earlier modules, `SPEC.md` was not available,
so the scope and Done-when test below were written for this module. Confirm
them.

## What was built

- **Arrival time for my stop** at the top of the student home:
  "Arrives in 12 min · around 7:38 AM".
- **At the stop:** within 150 m either side it reads "The bus is at your stop
  now".
- **Bus-passed indicator:** once the bus is beyond the stop, or the driver's
  phone recorded a stop time there this trip, it reads "Passed your stop at
  7:42 AM" (or without a time if none was recorded).
- **Full route view** ("See all stops" on the stop card): every stop in
  travel order, with "Passed at 7:11 AM", "Bus is here" between the last
  passed and the next stop, "Expected 7:38 AM" for the rest, and the
  scheduled time on morning trips. The student's stop is marked.
- **How the estimate works:**
  1. The bus position is projected onto the route's road path, giving its
     distance along the route and how far off the road it is.
  2. Each stop gets its own distance along the same path.
  3. The time between two points is read off the timetable, stretch by
     stretch: halfway between two stops 10 scheduled minutes apart is 5
     minutes from the next. Before the first stop, after the last, or with
     no usable timetable, it uses 25 km/h.
  4. The expected time counts from when the position was sent, so it does
     not drift later while updates are delayed.
- **Edge cases:** evening trips run the route backwards (direction comes from
  the trip ID). A bus more than 500 m off its road gets "The bus is away from
  its usual route" instead of a wrong time. An offline bus gets no estimate,
  only the schedule, unless a stop time already proves it passed. On a weak
  signal the estimate carries "Estimated from the last known position".

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Timetable-based time per stretch, not one average speed | Same idea as "distance along the route divided by average speed", but follows the slow and fast parts of each route. Module 11 replaces it with times learned from recorded trips. |
| 150 m counts as "at the stop" | A bus bay plus GPS error; wider than the 80 m the driver's phone uses to record a stop. |
| Recorded stop times win | The phone's record is certain; a position past the stop can be GPS noise. |
| Scheduled times hidden on evening trips | The timetable holds morning times only. |

## Done when

With `npm run emulators`, `npm run seed`, the app on the web and
`npm run simulate-bus`:

| # | Check | Result |
| --- | --- | --- |
| 1 | A student whose bus is on its way sees minutes to their stop and the clock time, and the minutes fall as the bus moves. | Pass (web, live: 34 → 22 min) |
| 2 | Near the stop it says the bus is at the stop. | Pass (widget test) |
| 3 | Past the stop it says so, with the recorded time when there is one. | Pass (web, live without time; widget test with time) |
| 4 | The full route view lists every stop in order with passed, bus position, expected and scheduled times, and marks the student's stop. | Pass (web, live; widget test) |
| 5 | Evening direction, off-route and no-timetable cases behave as described. | Pass (unit tests) |
| 6 | An offline bus shows no estimate. | Pass (widget test) |
| 7 | `flutter test` passes. | Pass: 78 app tests |

## Known gaps

- Estimates follow the placeholder timetable in `data/base-data.json`; real
  timings from the transport office will make them meaningful.
- A route whose road passes close to itself could place the bus on the wrong
  stretch. None of the demo routes do; worth checking with real routes.
- Delay and approaching alerts built on this estimate are Module 6.
