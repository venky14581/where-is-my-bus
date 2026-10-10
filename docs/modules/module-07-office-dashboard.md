# Module 7: Office dashboard

Status: **done**, 11 Oct 2026. Tested in the browser against the emulators,
with a simulated bus on the road. As with earlier modules, `SPEC.md` was not
available, so the scope and Done-when test below were written for this
module. Confirm them.

## What was built

The React dashboard (`dashboard/`) now has six pages, reached from a sidebar
(addresses like `#/buses`, so links and reloads work):

- **Live map:** every bus on a Leaflet map, green when live and grey on weak
  signal or offline, with its route path, a tooltip (bus, route, driver,
  status, age) and a table of all buses. Clicking a row flies to that bus.
  Same live/stale/offline/not-running rules as the student app, using the
  server's clock.
- **Buses:** add and edit number, seats, route and driver. A driver drives
  one bus: assigning them elsewhere takes them off their old bus in the same
  write. Delete with confirmation.
- **Routes and stops:**
  - Edit the route name, city, guest fare and whether students see it.
  - Stops are listed in travel order with a name, time and position. Click
    the map to add a stop, or "Place" then click to move one; reorder or
    remove them.
  - Saving checks for problems in plain words (missing names, positions or
    times, times out of order), and warns before removing stops that
    students have chosen.
  - It then rebuilds the road path through OSRM and lists any stop more
    than 50 m from the road, with "Save anyway".
  - Stop IDs never change when a stop is renamed, so students keep their
    choice.
- **Drivers:** add a driver (ID, name, generated 6-digit PIN) and give one a
  new PIN. The PIN is shown once, to hand over. Both go through office-only
  callable Cloud Functions (`createDriver`, `setDriverPin`), since only the
  admin SDK can create someone else's login or change their password.
- **Announcements:** to one route's riders or to all students, with
  confirmation, plus the last 20 sent. Module 6's function delivers them.
- **Fares and booking:** the booking window (opens the evening before at a
  set time, closes 20 or 30 minutes before departure) in `settings/booking`,
  and the guest fare per route on `routes/{id}.guestFare`. Both are used in
  Module 10.

Server side:

- `mirrorBusDriver` function: keeps the Realtime Database `busDrivers/{busId}`
  mirror in step with `buses/{busId}.driverId`, whoever edits the bus.
  Before, two separate writes could drift apart.
- Rules now validate office edits: a route needs a name, a city, 2–60 stops
  and a `stopIds` list of the same length, and a fare of ₹0–1000. A bus needs
  a number, 1–120 seats, and a route that exists. Plus rules for `settings`.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Driver accounts through callable functions | The browser SDK cannot create another user's login or set their password. |
| Mirror written by a function, not the dashboard | One write from the office, and the mirror cannot drift. |
| OSRM called from the dashboard when saving a route | Paths change only when stops do; the office sees the result and any off-road stops before saving. |
| No router library | Six pages; hash addresses are enough. |
| Reports (ridership, punctuality, history) not here | Module 12, per the module plan. |

## Done when

With `npm run emulators`, `npm run seed`, `npm run simulate-bus` and
`npm --prefix dashboard run dev`, signed in as the office:

| # | Check | Result |
| --- | --- | --- |
| 1 | The live map shows the moving bus in green with route, driver and age; the table lists every bus. | Pass (live) |
| 2 | Adding driver DRV003 shows their PIN once, and that ID and PIN sign in; a wrong PIN does not. | Pass (live) |
| 3 | Assigning DRV003 to a bus updates `busDrivers` in the rules-enforced database instance. | Pass (live, after fixing the instance name) |
| 4 | Saving a route rebuilds its road path and distances, keeps stop IDs, and warns about off-road stops before saving. | Pass (live: Ettimadai Pirivu 327 m and campus 82 m flagged) |
| 5 | An announcement to all students reaches them. | Pass (live; `pushLog`) |
| 6 | Booking window and guest fares save. | Pass (live) |
| 7 | Rules reject a route without matching `stopIds`, fewer than 2 stops, a negative fare, 0 seats or an unknown route. | Pass (rules tests) |
| 8 | Tests pass. | Pass: 15 function, 52 rules, 8 dashboard tests; dashboard builds and lints clean |

## Bugs found while testing

- The mirror function wrote to the emulator's project-named database, which
  has no rules and that nothing reads. Fixed, with a test: on the emulator it
  now always uses the `-default-rtdb` instance.
- The route editor's stop-name fields shrank to one letter on narrow
  screens. They now keep a usable width and the table scrolls sideways.
- A stop out of time order was missed when a stop with a bad time sat
  between them. Fixed, with a test.

## Known gaps

- Cancelling a trip and naming a replacement bus is not built (the
  breakdown alert says to watch for office news; use an announcement).
- Deleting a route is not offered (buses and students point at it);
  "Shown to students" hides it instead.
- Drivers cannot be removed yet, only given a new PIN.
- `routeAccess` (which routes accept riders from which, for Module 9) has no
  editing screen yet; Module 9 adds it where it is used.
