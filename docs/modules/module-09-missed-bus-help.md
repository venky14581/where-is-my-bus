# Module 9: Missed-bus help

Status: **built and tested on the emulators and the web app, 11 Oct 2026.**
As with earlier modules, `SPEC.md` was not available, so the scope and
Done-when test below were written for this module. Confirm them.

## What was built

- **"Missed your bus?"** on the student home opens a list of other college
  buses the student may ride. A bus qualifies when:
  - its route accepts riders from the student's route (`routeAccess`, set by
    the transport office);
  - it is running today with a fresh position;
  - the student holds a valid pass.
- **For each bus:**
  - the bus number and route, with the bus live on a map;
  - **where to get on:** the nearest stop on that route the student can walk
    to before the bus arrives;
  - the walk ("300 m walk, about 5 min") and when the bus gets there ("Bus
    there in 11 min, around 7:38 AM");
  - seats left for other routes.

  If no stop can be reached in time, the nearest one is shown with "The bus
  may get there before you." Buses come in order: reachable first, then
  soonest.
- **Where the student is:** the phone's location, read once on this screen
  and used only to pick the nearest stop. It is never sent anywhere, as
  `CLAUDE.md` requires. Without location permission the student's usual stop
  is used, and the screen says so.
- **Hold a seat:** the server checks the pass, the route access, that the
  bus is running and has not passed the stop, and that a seat is free. Then
  it holds one. The card reads "Seat held. Be at Kovaipudur Pirivu and show
  your pass to the driver." with a "Give up seat" button. Holding on another
  bus gives up the earlier seat, so each student holds only one.
- **The seat goes back** when the bus records a stop past the student's
  pickup stop. The student sees "The bus left Kovaipudur Pirivu, so your
  seat was released."
- **Driver:** while a trip runs, "Riders from other routes" lists who is
  waiting where, in stop order, so the driver knows to stop.
- **Boarding:** the driver scans the pass as usual (Module 8).
  - A rider from another route boards only with a seat held on that bus.
    Without one, the scanner says "{name} has no seat held on this bus.
    They can hold one in the app."
  - Boarding marks the hold as used, and the record says `alternate`.
- **Seat counting (server only):**
  - When a trip starts, `countTripSeats` counts the route's valid passes
    (`passHolders`). Those seats are kept for them, since pass holders keep
    priority (`CLAUDE.md`).
  - Other routes get what is left: capacity − passHolders − held seats
    (`altHeld`).
  - Every change happens in a transaction, so two students cannot get the
    last seat.
- **Simulator:** `npm run simulate-bus -- bus-02 --trip` also creates the
  trip and records stop times, so all of this can be tried without phones.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Holds at `trips/{tripId}/holds/{uid}`, not `holds/{tripId}/{uid}` | Same reason as boardings in Module 8: Firestore paths alternate collection and document. |
| A held seat is needed to board another route's bus | Keeps the seat count true, so a bus never fills with riders it did not plan for. This narrows Module 8, where any authorized route could board. |
| Every pass holder of the route keeps a seat, riding or not | Pass holders have priority. Module 10's "not riding today" can free seats later. |
| Only official stops are offered as pickup points | They are where buses may stop safely. The "safe pickup point" in the features document. |
| Walking distance = straight line × 1.3 at 4.5 km/h, plus 2 minutes to spare | No walking-route service is in the stack. Generous enough for a student with a bag. |
| Seat released once the bus records a later stop, not at the pickup stop | The rider may still be boarding when the stop time is recorded. |
| Bus time from the timetable model of Module 5 | Same estimate the student already sees for their own bus. |

## Done when

With `npm run emulators`, `npm run seed`, and the demo student given the
Gandhipuram route and a pass:

| # | Check | Result |
| --- | --- | --- |
| 1 | The screen lists only buses whose route accepts the student's route, with the nearest reachable stop, the walk, the bus time and seats. | Pass (web, live: R.S. Puram bus, Kovaipudur Pirivu, 300 m, 11 min, 50 seats; unit tests) |
| 2 | Holding a seat counts it once; holding again does not take a second seat. | Pass (live: `held`, `held`, altHeld 1) |
| 3 | Holding is refused for a route not allowed, a stop that is not a pickup stop, a stop already passed, a full bus, and without a pass. | Pass (live for the first four: `notAllowed`, `badStop`, `passed`, `full`; widget test for no pass) |
| 4 | Two students racing for the last seat: one gets it. | Pass (live: `held` / `full`, altHeld 1) |
| 5 | The driver sees who to expect where; the student reads only their own hold. | Pass (live through the rules; widget test; rules tests) |
| 6 | Giving up the seat frees it. Without a held seat the pass is refused on another route's bus; with one it boards as `alternate`. | Pass (live: `cancelled`, altHeld 0, `noSeatHeld`, then `boarded`, type `alternate`) |
| 7 | The seat goes back once the bus leaves the pickup stop behind, not at the stop itself, and the student is told. | Pass (live, both directions; web screen showed the message) |
| 8 | Tests pass. | Pass: 99 app, 28 function, 57 rules, 9 dashboard tests |

## Known gaps

- **Real stop data:** the placeholder stops sit up to 330 m off the road.
  A driver's phone, which records a stop within 80 m, would not record
  them, so seats held there would be released only at a later stop. The
  real list from the transport office fixes this.
- **Walking times are rough.** A footbridge or a fenced highway can make a
  near stop far.
- **No push notification** when a seat is released. The student sees it in
  the app only.
- Seats freed by pass holders who are not riding wait for Module 10.
- Location on a phone (permission prompt, indoor fixes) is still to be
  tried on a device.
