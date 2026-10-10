# Module 3: Driver trip and GPS

Status: **built and tested on web and the emulators; the phone test is still
open.** As with earlier modules, `SPEC.md` was not available, so the scope
and Done-when test below were written for this module. Confirm them.

Background tracking with the screen off can only be checked on a real
Android phone (check 9). This machine has no Android SDK yet, so the module
is not done until that check passes.

## What was built

- **Driver home:** one large Start Trip / End Trip button. End Trip asks for
  confirmation. While a trip runs, the screen shows "Sharing bus location",
  how long ago the last position was sent, whether there is signal, the next
  stop and how many stops have been reached. The sign-out menu is hidden
  mid-trip.
- **Direction:** trips before noon go to the campus, later trips come back.
  The trip ID is `{date}_{busId}_{direction}`, so pressing Start again the
  same morning resumes that trip instead of creating a second one.
- **Position sharing:** the latest reading goes to `live/{busId}` in the
  Realtime Database at most every 3 seconds, with the server's time. Only the
  newest point is stored, never a history.
- **Weak network:** while offline the phone keeps only the newest point and
  sends it when the signal returns. If the connection drops, the server marks
  the bus `offline` by itself, so students can grey out the marker (Module 4).
- **Fake GPS protection:** readings from mock-location apps are never sent
  and the driver sees a warning. Readings worse than 100 m, or implying more
  than about 120 km/h since the last good one, are dropped. If five in a row
  disagree with the last good reading, that reading was the bad one and the
  filter starts over.
- **Stop times:** when the bus comes within 80 m of a stop, the phone records
  `trips/{tripId}/stopTimes/{stopId}` with the time it was there. Firestore
  queues these offline. This is the trip history Module 11 needs.
- **Resume:** the trip in progress is saved on the phone (Hive). If the app
  is closed mid-trip, it picks the trip up again when the driver home opens,
  without a tap, and keeps the stops already reached.
- **Background:** on Android, a `flutter_foreground_task` service of type
  `location` keeps the app alive with a "trip in progress" notification, so
  positions keep flowing with the screen off or another app open, without
  "allow all the time" location permission. iOS has the location background
  mode and permission texts.
- **Simulated drive** (debug builds only): `--dart-define=SIMULATE_DRIVE=true`
  drives the bus along the route's road path at about 40 km/h, five times
  faster than real time. Used for testing without a phone and for demos.
- **Security rules:**
  - `trips` and `stopTimes`: only the driver the office assigned to that bus
    can start, end or resume its trips, and only stops on that route can be
    recorded, only while the trip runs. College accounts can read them.
  - `live/{busId}`: only that bus's driver can write it, every field is
    checked (ranges, allowed statuses, no extra fields), and only verified
    students, drivers and the office can read it.
  - The Realtime Database rules cannot read Firestore, so the import also
    writes `busDrivers/{busId}` (who drives which bus) and `officeUids`.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Tracking runs in the app, kept alive by a location foreground service | Simpler than a separate background isolate with its own Firebase setup. Covers screen off and other apps open. If the driver swipes the app away from recent apps, tracking stops (see Known gaps). |
| Direction from the time of day, not a driver choice | Keeps the driver screen to one button. |
| Bus marked offline by the server on disconnect, after the first position | The rules require a position before any status, so the marker is registered right after the first write, once per connection. |
| `busDrivers` mirror in the Realtime Database | Its rules cannot look up Firestore. Whoever changes a bus's driver must update both (the import does; the Module 7 dashboard must too). |
| `permission_handler` not used | `geolocator` handles location permission (including on the web) and the foreground-task plugin handles notification permission. Add it back when a module needs another permission. |
| Realtime Database instance `<projectId>-default-rtdb` | The emulator applies `database.rules.json` only to that instance, as production does. An earlier version used another name and ran with open rules. |

## Done when

With `npm run emulators` and `npm run seed`, and the app on the web with a
simulated drive (`flutter run -d chrome --dart-define=SIMULATE_DRIVE=true`):

| # | Check | Result |
| --- | --- | --- |
| 1 | Start Trip creates `trips/{date}_{busId}_{direction}` with status running, and `live/{busId}` updates every few seconds with real coordinates and server time. | Pass (web, live) |
| 2 | Stop times appear under the trip when the bus reaches a stop. | Pass (web, live: Madukkarai) |
| 3 | When the driver's connection drops, `live/{busId}` shows `offline` within seconds. | Pass (web, live, about 1 s) |
| 4 | Reopening the app mid-trip resumes the same trip without a tap, and the bus shows `running` again. | Pass (web, live) |
| 5 | End Trip, after confirming, sets the bus to `ended` and closes the trip with an end time. | Pass (web, live) |
| 6 | Fake GPS readings are not sent and the driver is warned; impossible jumps are dropped; location off or permission refused is explained, with a button to open settings. | Pass (unit and widget tests) |
| 7 | Offline, only the newest point is kept and sent when the signal returns. | Pass (controller test) |
| 8 | Only the assigned driver can write `live/{busId}` or run that bus's trips; bad values are refused; only college accounts can read positions. | Pass (rules tests) |
| 9 | **On an Android phone:** with the screen off for 5 minutes during a trip, `live/{busId}` keeps updating, and the notification is shown. | **Not run: no Android SDK on this machine** |
| 10 | `flutter test` and `npm run test:rules` pass. | Pass: 57 app tests, 40 rules tests |

## Known gaps

- **Check 9 is not done.** Install Android Studio, connect a phone, and run
  it before calling Module 3 finished. See "On an Android phone" in the
  README.
- If the driver swipes the app away from recent apps, tracking stops until
  they open it again (it then resumes by itself). The bus shows `offline`
  meanwhile. Fixing this means moving tracking into the foreground task's own
  isolate; worth doing only if pilot drivers actually do this.
- Several placeholder stops are too far from the road to be recorded
  (Ettimadai Pirivu 327 m, the campus 82 m, Chandranagar 84 m, Walayar
  108 m). `npm run build-paths` now warns about this. Real roadside
  coordinates from the transport office will fix it.
- Simulated trips record stop times in the simulation's faster clock. They
  only ever reach the local emulators.
- Not built yet, from the driver feature list: auto-start when the bus
  leaves the depot, the Running late and Breakdown buttons (Module 6), and
  bus swap.
