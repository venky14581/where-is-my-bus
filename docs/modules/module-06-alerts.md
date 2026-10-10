# Module 6: Alerts

Status: **built and tested on the emulators; real push delivery is still
open.** As with earlier modules, `SPEC.md` was not available, so the scope and
Done-when test below were written for this module. Confirm them.

Delivery to a phone needs a real Firebase project (FCM cannot deliver on the
emulators' demo project) and an Android phone (check 9). Everything up to the
point of sending is tested.

## What was built

- **Cloud Functions** (`functions/`, TypeScript, region `asia-south1`). They
  fire on trips, stop times, driver reports and announcements, never on
  position updates:

  | Alert | Fires when | Goes to |
  | --- | --- | --- |
  | Trip started | a trip is created | riders of the route |
  | Approaching | the bus reaches a stop, and the student's stop is within their 1–3 stops or 5 scheduled minutes ahead | that student, once per trip |
  | Delay | a morning stop time is 10+ min behind the timetable, and again each further 10 min | riders of the route |
  | Running late, Breakdown | the driver taps the button | riders of the route |
  | Announcement | the office posts one, to a route or to all | those students |

- **Per-student settings** are applied on the server: each kind on or off,
  how many stops ahead, and quiet days (breakdowns still get through).
  Messages are written in the student's language.
- **Delivery:** FCM to every device the student registered. Tokens FCM
  reports as dead are deleted. On the emulators each message is written to
  `pushLog` instead, so you can see who would have been told what.
- **Safe to repeat:** triggers are delivered at least once, and "trip
  started" was seen arriving twice. Each alert claims a marker in
  `functionRuns` (or `approachingSent`, or a transaction for delays) so it
  is sent once.
- **App, students:**
  - Bell icon with an unread count, opening an alerts list: trip news from
    the last day and announcements from the last week. It works with push
    off or denied.
  - Notification settings screen (from the alerts list); every change saves
    at once.
  - The device registers for push after the student is verified, and is
    removed on sign-out.
- **App, drivers:** Running late (one tap) and Breakdown (asks first)
  buttons while a trip runs, each usable once per trip, with the result shown
  under the buttons.
- **Rules** for alert settings, devices, driver reports, the alerts list and
  announcements; server-only collections stay closed. Composite indexes for
  the alerts list queries are in `firestore.indexes.json`.
- **`npm run announce`** posts an announcement until the dashboard has a
  screen for it (Module 7).

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Push to device tokens, not FCM topics | Topics cannot apply per-student settings, lead stops or quiet days. Fine at college scale. |
| An in-app alerts list as well as push | Push can be denied, and does not work on the web build. |
| Breakdowns ignore quiet days | A student may still be about to travel. |
| Delay alerts only on morning trips | The timetable holds morning times only. |
| Driver buttons once per trip | Stops a nervous tap from spamming every rider. |
| `npm run emulators` waits up to 60 s for functions to load | A cold first load took 18 s on this Windows machine (antivirus scanning `node_modules`); the emulator's default is 10 s. Warm loads take under 1 s. |

## Done when

With `npm run emulators` and `npm run seed`, writing what the driver's phone
writes:

| # | Check | Result |
| --- | --- | --- |
| 1 | Starting a trip puts "has started its trip" in the route's alerts list and pushes it to riders, once. | Pass (emulator: once, after the idempotency fix) |
| 2 | Reaching a stop pushes "your bus is coming" to a student 2 stops ahead, once per trip. | Pass (emulator) |
| 3 | A stop 11 min late sends one delay alert; a later stop still 11 min late sends none. | Pass (emulator) |
| 4 | A breakdown report reaches the list and every rider. | Pass (emulator) |
| 5 | An announcement to all reaches every student. | Pass (emulator) |
| 6 | A student who switches off "Delays and breakdowns" in the app still sees a running-late alert in the list but gets no push; switching it back on restores the push. | Pass (web app + emulator) |
| 7 | The alerts list shows these, newest first, with an unread count. | Pass (web, live) |
| 8 | Rules: only the trip's driver can report; only the office announces; settings are validated; server-only paths stay closed. Decision logic: lead stops, 5 minutes, evening direction, quiet days, delay steps, both languages. | Pass: 50 rules tests, 12 function tests, 83 app tests |
| 9 | **On a phone, with a real project:** a notification arrives with the app closed, and in the foreground. | **Not run: needs a real Firebase project and an Android phone** |

## Known gaps

- **Check 9.** Needs `flutterfire configure` against a real project, the
  pay-as-you-go plan (Cloud Functions do not deploy on the free plan), and a
  phone.
- Push on the web would need a VAPID key and a service worker; not set up,
  since students use the phone app.
- Office cancellation of a trip with a replacement bus, and route-change
  notices, come with the dashboard (Module 7); both are announcements today.
- `pushLog` and `functionRuns` grow without limit on the emulators. Real
  deployments write no `pushLog`; `functionRuns` needs a TTL policy before
  launch.
