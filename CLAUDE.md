# Where Is My Bus: project handoff

This file carries the full context of the planning chat so work can continue in Claude Code. The planning chat referred to a full specification in `SPEC.md`, but that file was never saved (checked 10 Oct 2026). Until it turns up, each module's Build and Done-when test is written in `docs/modules/` before the module is called done. The features document is `Where Is My Bus - Problem Statement Solution and Features.pdf` (the 3-second version).

## What the project is

A mobile app that shows day scholars at Amrita Vishwa Vidyapeetham, Coimbatore (Ettimadai campus) the live location and arrival time of their college bus. The driver's smartphone is the only tracker. No GPS hardware is fitted in the bus.

Users: driver (driver mode in the app), day scholar (student app), hosteller or own-transport student (books spare evening seats), transport office (web dashboard), parent (shared trip link).

## Status

- Module 1 (Setup and login): done 10 Oct 2026. See `docs/modules/module-01-setup-and-login.md`.
- Module 2 (Route and bus data): done 10 Oct 2026. See `docs/modules/module-02-route-and-bus-data.md`. The route data in `data/base-data.json` is a placeholder until the transport office supplies the real stops and timings.
- Module 3 (Driver trip and GPS): built and tested on web with a simulated drive, 10 Oct 2026. See `docs/modules/module-03-driver-trip-and-gps.md`. Not done until the screen-off test on a real Android phone passes (needs Android Studio).
- Module 4 (Live map): done 10 Oct 2026. See `docs/modules/module-04-live-map.md`.
- Module 5 (Arrival time): done 10 Oct 2026. See `docs/modules/module-05-arrival-time.md`.
- Module 6 (Alerts): built and tested on the emulators, 11 Oct 2026. See `docs/modules/module-06-alerts.md`. Real push delivery still needs a real Firebase project (pay-as-you-go plan for Cloud Functions) and a phone.
- Module 7 (Office dashboard): done 11 Oct 2026. See `docs/modules/module-07-office-dashboard.md`.
- Module 8 (Pass and QR scan): built and tested on the emulators, 11 Oct 2026. See `docs/modules/module-08-pass-and-qr-scan.md`. The camera scan needs a phone.
- Next step: Module 9 (Missed-bus help). Still open on a real Android phone: Module 3 screen-off tracking, Module 6 push, Module 8 camera scan.

## Decisions made in the planning chat, in order

1. Started from a list of college problems solvable with software and chose bus tracking for day scholars.
2. Location source is the driver's phone only. No tracker hardware. Crowdsourcing from students' phones was considered and set aside.
3. The target campus is Amrita Coimbatore. Day scholars travel from Coimbatore, Palakkad and other towns, so the student picks city, then route, then stop.
4. Evening seat booking was added: students without a bus pass (hostellers, own-transport students, day scholars wanting a different route) book a spare seat on an evening bus and pay per ride.
5. Alternate bus suggestion was added: when a student misses the assigned bus, the app offers another authorized college bus passing nearby, with live location, arrival time, nearest safe pickup point, route and seat availability. Boarding is allowed only on a bus authorized to carry that student.
6. Live location is sent every 3 seconds during an active trip. If the bus goes offline, the marker turns grey and shows the last updated time.
7. Booking window: opens at 6 pm the day before the trip and closes 20 to 30 minutes before departure.
8. Removed from scope. Do not build these:
   - Hosteller permission or gate-pass check before booking
   - Auto sharing from Ettimadai Pirivu
   - Late-stay ride pooling
9. The work is split into 13 modules in six stages. The old phase-based build order was replaced by this module plan.

## Module order

| Stage | Modules | Result |
| --- | --- | --- |
| 1 Foundation | 1 Setup and login, 2 Route and bus data | Accounts and base data |
| 2 Tracking core | 3 Driver trip and GPS, 4 Live map, 5 Arrival time | Working demo |
| 3 Usable app | 6 Alerts, 7 Office dashboard, 8 Pass and QR scan | Ready for a one-route pilot |
| 4 Stand-out features | 9 Missed-bus help, 10 Evening seat booking | What sets the project apart |
| 5 Smart and safety | 11 Smart features, 12 Safety and reports | Machine learning and reports |
| 6 Release | 13 Testing and pilot | Tested on one real route |

Each module in `SPEC.md` lists Build, Tools, Data and a Done when test. Finish and test one module before starting the next.

## Tech stack

Use exactly these. Where `SPEC.md` says "Flutter Web or React", the dashboard is React.

### Mobile app (student and driver)

| Purpose | Choice |
| --- | --- |
| Framework | Flutter (Dart), one codebase for Android and iOS, role chosen at login |
| State management | Riverpod (`flutter_riverpod`) |
| Navigation | `go_router` |
| Maps | `flutter_map` with OpenStreetMap tiles, `latlong2` for distances |
| GPS | `geolocator` |
| Background tracking | `flutter_foreground_task` |
| Offline queue | `hive` |
| Notifications | `firebase_messaging`, `flutter_local_notifications` |
| QR pass and scanner | `qr_flutter`, `mobile_scanner` |
| Payments (demo) | `razorpay_flutter` in test mode |
| Languages | `flutter_localizations` with `intl` (Tamil and English) |
| Permissions | `permission_handler` |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_database`, `cloud_functions`, `firebase_app_check` |

### Backend (Firebase)

| Purpose | Choice |
| --- | --- |
| Login | Firebase Authentication (college email for students, ID and PIN for drivers in the demo) |
| Live bus position | Firebase Realtime Database at `live/{busId}` |
| All other data | Cloud Firestore |
| Server logic | Cloud Functions in TypeScript on Node.js (alerts, pass verification, seat holds, booking) |
| Scheduled jobs | Scheduled Cloud Functions (create evening trips, open and close booking) |
| Push notifications | Firebase Cloud Messaging |
| Abuse protection | Firebase App Check, Firestore and Realtime Database security rules |
| Hosting | Firebase Hosting (dashboard and parent trip link) |

### Transport office dashboard (web)

| Purpose | Choice |
| --- | --- |
| Framework | React with Vite and TypeScript |
| Map | Leaflet (`react-leaflet`) |
| Charts | Chart.js |
| Data | Firebase JavaScript SDK |

### Routing and prediction

| Purpose | Choice |
| --- | --- |
| Route paths between stops | OSRM |
| Arrival-time model | Python with pandas and scikit-learn |
| Notebook work | Jupyter |

### Development and testing

| Purpose | Choice |
| --- | --- |
| Editor | VS Code or Android Studio |
| Version control | Git and GitHub |
| Local backend | Firebase Emulator Suite |
| Tests | `flutter_test` for the app, `@firebase/rules-unit-testing` for security rules |
| Builds | GitHub Actions (optional) |

### Suggested folder layout

- `app/` Flutter app (student and driver)
- `dashboard/` React dashboard
- `functions/` Cloud Functions
- `ml/` Python prediction code
- `firestore.rules`, `database.rules.json`, `firebase.json` at the root

## Data model

- `users/{uid}`: name, role, routeId, stopId, passValid, passValidUntil (YYYY-MM-DD), language, alerts
- `passSecrets/{uid}`: secret behind the student's rotating pass QR (server-written)
- `routes/{routeId}`: name, city, ordered stops (name, lat, lng, scheduledTime), path
- `buses/{busId}`: number, capacity, routeId, driverId
- `live/{busId}`: lat, lng, speed, updatedAt, tripId, status
- `trips/{tripId}`: busId, routeId, date, direction, start and end time, capacity, passHolders, notRiding, seatsBooked, booking open and close time
- `trips/{tripId}/stopTimes`: actual time at each stop
- `trips/{tripId}/boardings/{uid}`: time, stop, type (pass, alternate, guest). (Planned as `boardings/{tripId}/{uid}`, which is not a valid Firestore path.)
- `holds/{tripId}/{uid}`: pickup stop, time
- `bookings/{bookingId}`: tripId, uid, stop, fare, status, ticket code
- `routeAccess/{routeId}`: routes it accepts riders from
- `announcements/{id}`, `timetable/{id}`, `settings/booking`, `segmentTimes/{routeId}`

## Rules to follow while building

- Only the bus location is shared. A student's own location stays on the phone.
- Only the latest position goes to `live/`. Do not store every 3-second point as history; store stop times.
- Trigger server functions on stop times, not on every position update.
- Check booking times, seat counts and pass validity on the server, never only in the app.
- Seat counts change inside a transaction so a seat cannot be sold twice.
- Pass holders always keep priority over guest riders.
- QR passes refresh every 30 seconds. QR tickets work for one scan only.
- Reject mock GPS locations on the driver's phone.
- Driver screens stay simple: one large Start Trip / End Trip button, Tamil and English.

## Known constraints

- Firebase's no-cost plan has no phone one-time passwords and no Cloud Functions, and allows 100 simultaneous Realtime Database connections (firebase.google.com/pricing, checked 10 Oct 2026). For the demo, drivers log in with an office-issued ID and PIN. Cloud Functions need the pay-as-you-go plan.
- 3-second updates drain the driver's phone, so it stays on a charger in the bus.
- Module 11 needs at least two weeks of recorded trips. Start recording as soon as Module 3 works.
- Public bus and train timings are entered by the transport office. They are fixed schedules, not live tracking.

## Open questions

- Guest riders: pay per ride (current assumption) or free with only a seat limit?
- Booking close time: fix it at 20 or at 30 minutes before departure?
- Which other towns do the college buses serve besides Coimbatore and Palakkad?
- Who is authorized on an alternate bus? Current assumption: the transport office sets which routes accept riders from which other routes, and the student holds a valid pass.
- Team size and deadline. The 13-week estimate assumes three people working part-time.
- The problem statement has not been confirmed with a survey of Amrita day scholars.
- Student email domain: assumed `cb.students.amrita.edu`. Confirm it, and whether any students use another domain. It is set in `app/lib/core/config.dart` and repeated in `firestore.rules`.

## Working in this repo

How to run and test everything is in `README.md`. Things that are easy to get wrong:

- Local development uses the Firebase emulators on the `demo-whereismybus` project. The app and dashboard switch to the emulators by themselves whenever the project ID starts with `demo-`. Start them with `npm run emulators`, then `npm run seed` (the emulators start empty).
- The emulators need Java 21 or newer.
- Driver login: driver ID `DRV001` signs in to Firebase Auth as `drv001@drivers.whereismybus.invalid` with the 6-digit PIN as password (`driverEmailFor` in `app/lib/features/auth/domain/credentials.dart`). Office-created driver accounts must use the same mapping.
- Which screens a role may open is decided only in `app/lib/routing/redirect.dart`; the rules enforce the same split on the server. Add new routes for a role under `/student/...` or `/driver/...` so they inherit it.
- `firestore.rules` closes every path not listed. Each module opens only the paths it needs and adds tests in `tests/rules/`.
- Routes, buses and route access come from `data/base-data.json`. After changing stops run `npm run build-paths` (OSRM) and then `npm run seed`. The last stop of every route is the campus.
- Live positions: Realtime Database instance `demo-whereismybus-default-rtdb` (the emulator only applies `database.rules.json` to `<projectId>-default-rtdb`; anything that builds a database URL must use that name, including Cloud Functions, where the emulator's FIREBASE_CONFIG points elsewhere). Its rules cannot read Firestore, so `busDrivers/{busId}` mirrors `buses/{busId}.driverId`; the `mirrorBusDriver` function keeps it in step, so just edit the bus.
- `--dart-define=SIMULATE_DRIVE=true` (debug builds only) drives the bus along its route without a phone. Simulated stop times use a 5× faster clock; never point a simulated build at a real project.
- On the web, avoid bitwise tricks on negative numbers (`~x`): web ints give unsigned 32-bit results. Run pure-logic tests with `flutter test --platform chrome` when in doubt.
- `npm run simulate-bus [busId]` moves a bus in the emulators without a driver, for working on student screens.
- `app/lib/l10n/generated/` gets deleted by **the first `flutter test` after a `flutter pub get`/`pub add`**, and the next `flutter run` then fails with "Error when reading 'lib/l10n/generated/app_localizations.dart'". Cause, confirmed from build-cache timestamps: `pub get` runs the localization step under its own build configuration, which records the generated files as its outputs; `flutter test` uses another configuration that records none, and on switching Flutter deletes the previous configuration's outputs (`trackSharedBuildDirectory` in flutter_tools). After adding packages, run `flutter gen-l10n` once more after the first test run. The files are committed, so `flutter gen-l10n` always restores them.
- Cloud Functions live in `functions/` (TypeScript). `npm run emulators` builds them first and allows 60 s for a cold load. They trigger on trips, stop times, reports and announcements only. Every trigger must be safe to run twice (delivery is at least once): claim a `functionRuns/{key}` marker or use a transaction. On the emulators, notifications go to `pushLog` instead of FCM.
- Driver logins are created and their PINs reset only through the office-only callable functions `createDriver` and `setDriverPin`.
- Pass QR codes: `functions/src/passCode.ts` and `app/lib/features/pass/domain/pass_code.dart` must produce identical codes; both test the same example. Boarding is decided only by the `scanPass` function.
- All user-facing app text goes in `app/lib/l10n/app_en.arb` and `app_ta.arb`, then `flutter gen-l10n`.
- A module is done when its Done-when table in `docs/modules/` passes. Update the Status section above when it does.
