# Module 12: Safety and reports

Status: **built and tested on the emulators, the web app and the dashboard,
11 Oct 2026.** As with earlier modules, `SPEC.md` was not available, so the
scope and Done-when test below were written for this module from the
features document ("Features: safety and security" and the dashboard's
reports). Confirm them. College-only login, role-based access, fake
location detection, student privacy and ticket protection from the same
list were built in Modules 1, 3, 8 and 10.

## What was built

### Safety

- **Overspeed and off-route alerts.** The driver's phone checks each good
  position (`SafetyMonitor`): above the office's speed limit for 10 seconds,
  or more than 300 m from the route's road for a minute, it writes one
  event to `trips/{tripId}/events`. A new episode is reported only after a
  minute back within limits, so a bus hovering at the limit does not flood
  the office. Detection is on the phone because server functions must not
  run on every position (CLAUDE.md); `onSafetyEvent` turns each event into
  a `safetyAlerts` document once. The limit is set on the dashboard
  (`settings/safety`, default 60 km/h).
- **SOS.** One button for the driver (under Running late / Breakdown) and
  for a student whose bus is running. It asks first, then `sendSos` sends
  the bus number, route, driver and the **bus's** position to the office;
  never the student's own location. Pressing again refreshes the same
  alert.
- **Share my trip.** A student with a running bus gets a link
  (`shareTrip`, a random 22-character token, `shares/{token}`) to copy to a
  parent. The parent opens it without signing in: the dashboard's
  `#/share/<token>` page shows that one bus on the map, the route and the
  student's stop, refreshed every 5 seconds through `viewSharedTrip`. Nothing
  about the student but their stop is shown. The link stops working when
  the trip ends, or after 12 hours.
- **Office.** A Safety alerts page (map and list, open first, Acknowledge),
  a count on its menu item, and a red banner on every page while an SOS is
  open.

### Reports (dashboard)

Over the last 7, 14 or 30 days, worked out in the browser from trips, their
stop times and boardings, and bookings (`dashboard/src/lib/reports.ts`):

- **Punctuality:** minutes late at campus per route (average, share on time
  within 5 minutes, worst), with a chart.
- **Ridership:** riders per day and route by kind (pass, other route,
  guest), and morning riders per stop.
- **Guest bookings:** guests, fares collected and no-shows per day and route.
- **Route suggestions:** stops averaging under one rider per trip, and
  routes at 90% of their seats on half their trips (once a route has 5
  morning trips).
- **Trip history:** any past trip on the map with its recorded stop times,
  its safety alerts, and a replay. Only stop times are stored, never every
  position (CLAUDE.md), so the bus between stops is estimated from them,
  and the page says so.

`npm run seed-history` fills the emulators with two weeks of synthetic past
trips (marked `synthetic: true`) so the reports can be tried.

## Done when

`npm run test:e2e` (`tests/e2e/m12-safety-reports.test.js`), the app's
`test/safety_monitor_test.dart`, `test/safety_test.dart` and
`test/trip_controller_test.dart`, `dashboard/src/lib/reports.test.ts`,
`functions/src/safety.test.ts`, `tests/rules/safety.rules.test.js`, and the
dashboard on the emulators with `npm run seed-history`:

| # | Check | Result |
| --- | --- | --- |
| 1 | A moment over the limit is not reported; 10 seconds over is, once; again only after a minute well under. Same for a minute off the route, with the distance. | Pass (unit and controller tests, with the office's limit) |
| 2 | An event from the driver becomes one office alert with bus, route and details; another driver cannot report on the trip. | Pass (e2e, rules tests) |
| 3 | SOS from the driver and from a student both reach the office with the bus's position; pressing again adds nothing; no running trip, nothing sent. The app asks before sending. | Pass (e2e, widget tests) |
| 4 | Only the office reads alerts and can only mark them acknowledged; the banner goes when the SOS is acknowledged. | Pass (rules tests, e2e; live) |
| 5 | A student shares a running trip; a parent sees that bus without signing in, with nothing identifying the student; a made-up token is refused; the link ends with the trip. | Pass (e2e, widget test; live: "Live · updated 2 s ago · Your student's stop: Madukkarai") |
| 6 | Reports give the right numbers: minutes late on the campus clock, riders by kind and stop, fares and no-shows, quiet stops and full routes, replay positions. | Pass (unit tests; live: 72 trips, 12 per route, Ettimadai Pirivu at 0.3 riders per trip flagged, ₹2420 from 69 guests) |
| 7 | Trip history shows a past trip's stops, its alerts and a replay that moves the bus. | Pass (live: replay 7:24 → 7:38, 1 alert shown) |
| 8 | Stop times that arrive for a trip already ended alert nobody. | Pass (e2e, two weeks of history loaded) |
| 9 | Tests pass. | Pass: 134 app, 42 function, 70 rules, 18 dashboard, 66 e2e, 3 Python tests; dashboard builds and lints clean |
| 10 | **On a phone:** the overspeed and off-route checks on a real drive, and SOS from the driver's screen. | **Not run: needs an Android phone** |

## Bugs found while building

- Saving the booking window on the dashboard replaced all of
  `settings/booking`, dropping the evening departure time Module 10 keeps
  there. It now merges.
- A stop time arriving after its trip ended (queued in a dead zone, or
  history loaded later) sent approaching and delay alerts for a bus already
  gone. `onStopReached` now skips ended trips.

## Known gaps

- **Check 10.**
- **Reports read every trip in the period** from the browser (stop times
  and boardings per trip). Fine for a pilot of a few buses; with many buses
  and 30 days it gets slow, and a nightly summary written by a scheduled
  function would be the next step.
- **No push for the office.** Alerts reach the dashboard while it is open;
  nobody is phoned or texted. An SOS needs someone watching the dashboard.
- **The parent's page polls every 5 seconds** through a function rather
  than listening to the database, so the live data stays closed to anyone
  without a college account. It has no App Check yet.
- **Share link base address**: the app builds links from
  `--dart-define=SHARE_BASE_URL` (default the local dashboard,
  `http://localhost:5173`). Set it to the hosting address for a real
  project.
- The trip replay is an estimate between stops; it cannot show a detour
  that the phone did not report as off-route.
