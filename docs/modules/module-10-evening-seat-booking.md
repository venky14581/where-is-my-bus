# Module 10: Evening seat booking

Status: **built and tested on the emulators, 11 Oct 2026.** As with earlier
modules, `SPEC.md` was not available, so the scope and Done-when test below
were written for this module. Confirm them.

## What was built

- **Evening trips made ahead.** A scheduled function (`createEveningTrips`,
  hourly) creates `trips/{date}_{busId}_fromCampus` for today (if the bus has
  not left) and tomorrow, for every bus with a route. Each trip is
  `scheduled` and carries its departure time, booking open and close times,
  capacity, the route's pass holders and the guest fare, fixed when the
  trip is made so a fare change does not alter what a student was quoted.
- **Booking window** from `settings/booking` (set on the dashboard):
  opens at `opensAt` (default 18:00) the evening before and closes
  `closesMinutesBefore` (default 30) before `eveningDepartsAt` (default
  16:30).
- **Who books.** Any verified student without a valid pass for that route:
  hostellers, students with their own transport, or a day scholar going
  somewhere else. A student can now say "I don't take a college bus every
  day" instead of choosing a route (`users/{uid}.dailyRider = false`); their
  home screen then offers evening seats.
- **Seats.** Spare seats are `capacity − passHolders − altHeld −
  seatsBooked`, one sum shared with missed-bus holds (Module 9), so the
  route's pass holders always keep theirs. `seatsBooked` changes only inside
  transactions; one booking per student per trip (`bookings/{tripId}_{uid}`).
- **Paying.** `bookSeat` keeps the seat for 10 minutes while the student pays.
  On the emulators a demo payment stands in. On a real project Razorpay is
  used, with keys from `functions/.env` (`RAZORPAY_KEY_ID`,
  `RAZORPAY_KEY_SECRET`, never committed); `payBooking` checks Razorpay's
  signature before issuing the ticket. Backing out of payment, cancelling,
  or not paying in time (`expireBookings`, every 5 minutes) gives the seat
  back. A paid seat is refunded by the transport office, not in the app.
- **Ticket.** A paid booking shows a QR (`WIMBT1.<bookingId>.<token>`) that
  works for one scan, on its own bus only. The driver scans it with the
  pass scanner; `scanPass` records a `guest` boarding at the nearest stop.
- **Starting an evening trip.** The driver's Start Trip turns the scheduled
  trip to `running`; `onTripStarted` now also fires on that change and
  stamps `startedAt`.

## Done when

`npm run test:e2e` runs these against the emulators
(`tests/e2e/m10-booking.test.js`):

| # | Check | Result |
| --- | --- | --- |
| 1 | Evening trips are made for every bus, today (if still to leave) and tomorrow, once however often the job runs, with the right departure, opening and closing times and fare. | Pass (e2e) |
| 2 | The server refuses: a pass holder of that route, getting off at campus or off the route, a route without guest seats, before opening, after closing, and a driver. | Pass (e2e) |
| 3 | A student books, pays and gets a ticket; asking again takes no second seat; someone else cannot pay it; paying without proof fails; a paid seat cannot be cancelled in the app. | Pass (e2e) |
| 4 | Cancelling or not paying in time gives the seat back, once; an expired booking cannot be paid. | Pass (e2e) |
| 5 | Two students racing for the last seat: one gets it, and the count never goes over. Pass holders' seats are never sold. | Pass (e2e) |
| 6 | The driver starts the scheduled trip; riders are told; booking stays open until it closes. | Pass (e2e) |
| 7 | A ticket boards once as `guest`, only on its own bus; a forged ticket fails. | Pass (e2e) |
| 8 | Only the student and the office read a booking; nobody writes one directly. A hosteller can say they take no daily bus. | Pass (e2e, rules tests) |
| 9 | The screens: list with fare, seats and times, book and pay, backing out, a full bus, the hosteller's path, the driver's ticket verdicts. | Pass (widget tests) |
| 10 | Tests pass. | Pass: 108 app, 34 function, 61 rules, 9 dashboard, 48 e2e tests |
| 11 | **With Razorpay test keys on a real project and a phone:** checkout opens, a test card pays, and the ticket appears. | **Not run: needs a real project and an Android phone** |

## Known gaps

- **Check 11.** Razorpay's checkout does not run on the web: there the app
  releases the seat and says payment was cancelled. Students use the phone
  app, so this only matters for testing on a real project from a browser.
- **The scheduled functions do not run on the emulators** (no Pub/Sub
  emulator), so the Evening seats screen is empty in local development
  unless something creates the trips. The e2e test calls the same code
  directly. A small `npm run evening-trips` script would help manual testing.
- **Refunds** of paid seats are by the transport office, outside the app.
- **Booking close time** is 30 minutes by default; the open question in
  `CLAUDE.md` (20 or 30) is a setting on the dashboard.
- **Pass holders who say they are not riding** do not yet free their seats
  (`notRiding` in the data model); the evening count assumes every pass
  holder rides.
- The ticket "for another bus" verdict is shown on the driver's phone in a
  widget test; the e2e test checks the server's answer.
