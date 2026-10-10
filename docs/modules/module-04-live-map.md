# Module 4: Live map

Status: **done**, 10 Oct 2026. Tested on Flutter web against the emulators
with simulated buses. As with earlier modules, `SPEC.md` was not available,
so the scope and Done-when test below were written for this module. Confirm
them.

## What was built

- **Student home is the map.** The top part shows OpenStreetMap with the
  route's road path, its stops (the student's own stop as a pin) and the bus.
  Below it: a status line, then the stop card (stop, route, bus number,
  scheduled time, Change).
- **The bus marker** glides between updates instead of jumping every 3
  seconds, and the map follows it. Panning or zooming stops following and
  shows a "Follow the bus" button.
- **How fresh the position is**, from the server's clock (so a phone with
  the wrong time still shows the right age):

  | State | When | Shown as |
  | --- | --- | --- |
  | Live | updated in the last 30 s | coloured marker, "Live · updated 4 s ago" |
  | Weak signal | running, no update for 30 s | grey marker, "Weak signal · last position 2 min ago" |
  | Offline | the server marked the driver's phone gone | grey marker, "Offline · last seen at 7:12 AM" |
  | Not running | trip ended, or no update for 2 hours | no marker, "The bus isn't running right now." |

- **All buses** (map icon in the app bar): every running bus on one map,
  fitted to show them all, with a list under it. Tapping a bus in the list
  or on the map follows it and draws its route.
- **Map attribution** "© OpenStreetMap contributors", as the tile policy
  requires.
- **`npm run simulate-bus [busId]`** moves a bus along its route in the
  emulators without a driver, so the student map can be tried in the one
  browser debug session. Ctrl+C marks it offline.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| The map is the student home, not a separate screen | "Open the app and know in five seconds where the bus is." |
| Weak signal after 30 s, not running after 2 hours | 30 s is ten missed 3-second updates. A trip never ended the evening before must not show as a bus on the road next morning. |
| Server time for ages | Uses the Realtime Database's server time offset. |
| The student's own location is not shown | Privacy rule in `CLAUDE.md`; the leave-home reminder (Module 11) uses it on the phone only. |
| Own attribution label | `flutter_map`'s built-in one cannot shrink and overflowed on narrow phones, especially in Tamil. |
| Public OpenStreetMap tile server | Fine at project scale. A wider launch needs its own tile provider, per the OSM tile usage policy. |

## Done when

With `npm run emulators`, `npm run seed`, the app on the web
(`flutter run -d chrome`) and `npm run simulate-bus`:

| # | Check | Result |
| --- | --- | --- |
| 1 | A student with a stop opens the app on a map of their route with the bus moving on it and "Live · updated n s ago". | Pass (web, live) |
| 2 | The map follows the bus; panning stops following and offers "Follow the bus". | Pass (web, live: follows; widget code for the button) |
| 3 | When the bus goes offline, its marker turns grey and the line shows the last-seen time. | Pass (web, live) |
| 4 | Weak signal after 30 s and "not running" after the trip ends are shown correctly. | Pass (widget tests) |
| 5 | A route with no bus says so. | Pass (widget test) |
| 6 | All buses shows every running bus fitted on the map with a list; tapping one follows it and shows its route; ended trips are left out. | Pass (web, live; widget test) |
| 7 | `flutter test` passes. | Pass: 64 app tests |

## Known gaps

- Arrival time for the student's stop and the bus-passed indicator are
  Module 5.
- Evening bay and departure time are not shown yet (needs bay data from the
  office).
- On a weak network the map tiles may load slowly; offline tile caching is
  not set up.
