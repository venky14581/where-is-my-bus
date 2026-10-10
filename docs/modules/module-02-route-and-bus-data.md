# Module 2: Route and bus data

Status: **done**, 10 Oct 2026. Tested on Flutter web and the Firebase
emulators. As with Module 1, `SPEC.md` was not available, so the scope and
Done-when test below were written for this module. Confirm them.

## What was built

- Firestore collections from the data model in `CLAUDE.md`:
  - `routes/{routeId}`: name, city, active, ordered `stops` (id, name, lat,
    lng, scheduledTime, distanceFromStartM), `stopIds`, `path` (encoded
    polyline from OSRM), distanceM.
  - `buses/{busId}`: number, capacity, routeId, driverId (the driver's uid).
  - `routeAccess/{routeId}`: acceptsFrom, for the alternate-bus rule in Module 9.
- `data/base-data.json`: the routes, buses and route access, in one file the
  team can edit. `npm run build-paths` fetches road paths and per-stop
  distances from OSRM into `data/route-paths.json`; `npm run seed` loads both.
- Security rules: base data readable by verified students, drivers and the
  office only; writable by the office only. A student can only save a stop
  that is on an existing route.
- App, student: after verifying their email, a new student picks city, then
  route, then home stop (the campus is excluded). The home screen shows stop,
  route, bus number and scheduled time, with Change.
- App, driver: the home screen shows the assigned bus, its route, stop count
  and first pickup. Start Trip stays off until Module 3.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Base data comes from a JSON file and an import script, not dashboard screens | Office editing screens belong to Module 7. The file is enough for a one-route pilot and works against a real project too. |
| The last stop of every route is the campus and is not offered as a home stop | Every morning route ends at the campus. |
| `scheduledTime` is the morning pickup time | Evening times arrive with trips (direction) in Module 3. |
| `stopIds` is stored next to `stops` | Security rules cannot search a list of maps, so they check the plain list. |
| Paths from the public OSRM demo server, saved in the repo | Paths change only when stops change, so the app never calls OSRM. |

## Done when

With `npm run emulators` and `npm run seed`:

| # | Check | Result |
| --- | --- | --- |
| 1 | `npm run seed` loads 3 routes with OSRM paths and 3 buses, with DRV001 and DRV002 assigned. | Pass |
| 2 | A verified student with no stop is taken to city → route → stop, and the choice is saved on their profile. | Pass (web, live; widget test) |
| 3 | The student home shows the stop, route, bus number and scheduled time, and Change lets them pick again. | Pass (web, live; widget test) |
| 4 | If the route or stop is removed, the student is asked to choose again. | Pass (widget test) |
| 5 | Driver DRV001 sees bus TN 37 AB 1201 on Gandhipuram – Campus. | Pass (web, live; widget test) |
| 6 | Unverified students, outsiders and signed-out users cannot read routes or buses; only the office can write them; a student cannot save a stop that is not on the route. | Pass (rules tests) |
| 7 | `flutter test` and `npm run test:rules` pass. | Pass: 33 app tests, 25 rules tests |

## Known gaps

- **The route data is made up.** Stop names are real places, but the
  coordinates and times are my approximations. Get the real routes, stops and
  timings from the transport office, put them in `data/base-data.json`, and
  run `npm run build-paths`.
- Route and stop names are English only. Tamil names for driver screens can
  be added as optional fields when the real data comes in.
- Not yet run on a phone (no Android SDK on the build machine).
