# Module 8: Pass and QR scan

Status: **built and tested on the emulators; the camera scan is still
open.** As with earlier modules, `SPEC.md` was not available, so the scope and
Done-when test below were written for this module. Confirm them.

The scanner uses the phone camera (`mobile_scanner`), which can only be tried
on a phone (check 8). Everything after the camera reads a code is tested.

## What was built

- **Digital bus pass** (student app, QR icon on the home screen): the
  student's name, "Valid until …", and a QR that changes every 30 seconds,
  with a countdown. A screenshot passed to a friend stops working within
  about a minute. No valid pass, or an expired one, shows a plain message
  instead.
- **The rotating code:** `WIMB1.<uid>.<30-second window>.<signature>`. The
  signature is an HMAC-SHA256 with a per-student secret
  (`passSecrets/{uid}`) that only that student and the server can read. The
  phone computes the code itself, so the pass shows offline. It uses the
  server's clock, so a phone with the wrong time still works. The Dart and
  TypeScript versions are tested against one shared example.
- **Driver scanner** ("Scan pass" while a trip runs): the camera above a
  large verdict that stays 3 seconds. A green ✓ "Asha – boarded" or
  "already boarded"; red or orange for not a pass, not genuine, an old code,
  no pass, an expired pass, not allowed on this bus, or no connection. A
  boarded count is shown. Repeated reads of the same QR are ignored for 5
  seconds.
- **`scanPass` function** (server decides, per `CLAUDE.md`):
  - It runs only for the driver of a running trip.
  - It checks the signature and time window (one window of slack either
    side), that the pass is valid and not past its last day (campus clock),
    and that the student is on this route or on one the office lets ride it
    (`routeAccess`).
  - It records `trips/{tripId}/boardings/{uid}` once per trip, with `type`
    (`pass`, or `alternate` for another authorized route), the name, and the
    nearest stop to the bus's live position.
- **`issuePassSecret` function:** gives a student a secret the first time the
  office marks their pass valid.
- **Dashboard → Bus passes:** students filtered by route or searched by name
  or email. Issue or extend a pass to a chosen end date (default 31 May, the
  end of the academic year), or cancel one, which stops the QR at once.
- **Rules:** a student reads only their own pass secret; nobody writes
  secrets or boardings from an app; only the office and the trip's driver
  read boardings.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Boardings at `trips/{tripId}/boardings/{uid}`, not `boardings/{tripId}/{uid}` as `CLAUDE.md` lists | Firestore paths alternate collection and document; this sits next to the trip's stop times. |
| HMAC code made on the phone, checked on the server | Works without signal at the stop; cannot be forged or moved to another student; screenshots expire. |
| One window of slack (up to about 90 s for a code's lifetime) | Covers clock drift and a slow scan without making screenshots useful. |
| Pass end date as `YYYY-MM-DD`, valid through that day | Matches how the office thinks about terms; the server checks it on the campus clock. |
| Boarding needs a connection | The driver's phone has no secrets to check codes itself. With no signal the driver sees "check the pass by eye". |

## Done when

With `npm run emulators`, `npm run seed` and a simulated bus:

| # | Check | Result |
| --- | --- | --- |
| 1 | The office issues a pass on the dashboard; the student's secret appears. | Pass (live) |
| 2 | The student's pass screen shows the QR with countdown and end date, and the QR is exactly the code the server expects. | Pass (live: screenshot decoded with OpenCV, identical to the server's code) |
| 3 | A valid code boards the student once, with the nearest stop recorded; scanning again says already boarded. | Pass (live, through the real `scanPass`) |
| 4 | A two-minute-old code, a tampered code and a non-pass QR are refused with different reasons. | Pass (live) |
| 5 | Wrong route, expired pass and cancelled pass are refused. | Pass (live) |
| 6 | The driver's scanner shows each verdict, ignores repeat reads and clears for the next student. | Pass (widget test, fake camera) |
| 7 | Tests pass: Dart and TypeScript agree on the shared example; rules. | Pass: 90 app, 22 function, 54 rules, 9 dashboard tests |
| 8 | **On a phone:** the camera reads a pass from another phone's screen. | **Not run: needs an Android phone** |

## Known gaps

- **Check 8.**
- Alternate-bus boarding is allowed for any route in `routeAccess`; Module 9
  narrows it to the bus actually offered to the student.
- No offline boarding: in a dead zone the driver checks by eye and the ride
  is not recorded.
- The pass shows no photo, so a friend with the student's unlocked phone
  could ride. Acceptable for a pilot; a photo needs consent and storage.
