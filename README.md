# Where Is My Bus

Live college bus tracking for Amrita Coimbatore day scholars. The driver's
phone is the only tracker. 

| Folder | What |
| --- | --- |
| `app/` | Flutter app: students and drivers (Android, iOS; web for development) |
| `dashboard/` | React dashboard for the transport office |
| `functions/` | Cloud Functions (TypeScript): alerts and announcements |
| `firestore.rules`, `database.rules.json` | Security rules |
| `data/` | Routes, buses and route access (`base-data.json`), and road paths from OSRM |
| `scripts/seed-emulators.mjs` | Loads demo accounts and `data/` into the local emulators |
| `scripts/simulate-bus.mjs` | Moves a bus along its route in the emulators (`npm run simulate-bus`) |
| `tests/rules/` | Security-rules tests |

## Requirements

- Flutter 3.38+ (`flutter doctor`)
- Node 22+ and the Firebase CLI (`npm install -g firebase-tools`)
- Java 21+ for the Firebase emulators. If `java -version` shows an older one,
  point `JAVA_HOME` (and `PATH`) at a newer JDK before starting the emulators.

## One-time setup

```bash
npm install
```

```bash
npm --prefix dashboard install
```

```bash
npm --prefix functions install
```

```bash
cd app && flutter pub get
```

## Run everything locally

Nothing here touches a real Firebase project: the app and dashboard use the
`demo-whereismybus` project, which only exists on the emulators.

1. Build the Cloud Functions and start the emulators, and leave them running
   (UI at http://localhost:4000):

   ```bash
   npm run emulators
   ```

2. In a second terminal, create the demo accounts (re-run after every emulator
   restart, since the emulators start empty):

   ```bash
   npm run seed
   ```

   The test passwords and driver PINs are in `scripts/seed-emulators.mjs`.
   After editing the stops in `data/base-data.json`, refresh the road paths
   first:

   ```bash
   npm run build-paths
   ```

3. Student and driver app in Chrome:

   ```bash
   cd app && flutter run -d chrome
   ```

   To try driver mode without a phone, add a simulated drive along the
   route (debug builds only):

   ```bash
   cd app && flutter run -d chrome --dart-define=SIMULATE_DRIVE=true
   ```

   Sign in as driver `DRV001`, tap Start Trip, and watch `live/bus-01` move
   in the Database tab of the emulator UI. Keep to one browser tab: a second
   tab of the same debug session stays blank.

   To see the student map without a driver, move a bus along its route in
   a third terminal (Ctrl+C leaves it marked offline):

   ```bash
   npm run simulate-bus
   ```

   For missed-bus help (riders from other routes holding a seat), the bus
   needs a real trip with stop times. Sign in as the demo student, give them
   a route and a pass, then drive another route's bus:

   ```bash
   npm run simulate-bus -- bus-02 --trip
   ```

   Stop the simulator with Ctrl+C in its own terminal. Stopping only the
   `npm` wrapper can leave the node process driving the same trip.

   Use `flutter run` (a debug build) for web. Do not use a release web build
   (`flutter build web`) with the emulators: when a page reload finds a
   signed-in user, Firebase Auth checks that user against production before
   the app can point it at the emulator, signs them out, and then refuses
   every sign-in until the page is reloaded again. Debug web builds, Android,
   iOS and real projects are not affected.

4. Office dashboard at http://localhost:5173 (live map, buses, routes and
   stops, drivers, bus passes, announcements, fares and booking):

   ```bash
   npm --prefix dashboard run dev
   ```

For the office reports and trip history, load two weeks of synthetic past
trips (after `npm run seed`):

```bash
npm run seed-history
```

A student's "Share my trip" link opens the dashboard's parent page,
`http://localhost:5173/#/share/<token>`, with no sign-in. For a real
project, build the app with `--dart-define=SHARE_BASE_URL=https://<project>.web.app`.

Push notifications are not sent anywhere either: on the emulators the alert
functions write each message to the `pushLog` collection (Firestore tab of
the emulator UI) instead. To post an announcement:

```bash
npm run announce -- "Holiday on Monday" "No buses run on Monday."
```

Verification emails are not sent anywhere. Open the link from the Auth tab of
the emulator UI (http://localhost:4000/auth), then tap **I've verified**.

### On an Android phone

Driver mode needs a real phone: background tracking with the screen off
can't be tested on the web. Install Android Studio first (it installs the
Android SDK), then check `flutter doctor`.

The app finds the emulators at `10.0.2.2` on the Android emulator. For a
physical phone on the same Wi-Fi, add `"host": "0.0.0.0"` to the `auth`,
`firestore` and `database` entries in `firebase.json`, then run:

```bash
cd app && flutter run --dart-define=EMULATOR_HOST=192.168.1.20
```

(replace the address with your computer's LAN IP).

To test background tracking: start a trip, turn the screen off for five
minutes, and check that `live/{busId}` keeps updating in the emulator UI and
that the "trip in progress" notification is showing.

## Tests

```bash
cd app && flutter test
```

```bash
npm run test:rules
```

```bash
npm run test:functions
```

```bash
npm --prefix dashboard test
```

The arrival-time model (Python 3.12):

```bash
py -3.12 -m venv ml/.venv
```

```bash
ml/.venv/Scripts/python -m pip install -r ml/requirements.txt
```

```bash
ml/.venv/Scripts/python -m unittest discover -s ml
```

End-to-end, every module's server side (sign-in, rules, Cloud Functions and
triggers) on the emulators. Starts and stops the emulators itself, or uses
the ones from `npm run emulators`. It empties and re-seeds them, so run
`npm run seed` again afterwards if you were using that data:

```bash
npm run test:e2e
```

## Learned arrival times

`ml/train.py` learns travel times between stops from past trips and writes
`ml/out/segment_times.json`, which `npm run seed` loads (or
`npm run import-ml` on its own). Until real trips are recorded it is trained
on synthetic ones:

```bash
cd ml && .venv/Scripts/python synth_trips.py && .venv/Scripts/python train.py
```

With recorded trips, export them first (`npm run export-trips`, add
`-- --project <id>` for a real project) and run only `train.py`. See
`docs/modules/module-11-smart-features.md`.

## Connecting a real Firebase project (the pilot)

Step by step in [docs/pilot/pilot-plan.md](docs/pilot/pilot-plan.md): create
the project (pay-as-you-go, for Cloud Functions), run `flutterfire configure`
in `app/`, fill in `dashboard/.env.local`, deploy with
`firebase deploy --only firestore,database,functions,hosting`, load the
office's routes, and check:

```bash
npm run import-routes -- --stops stops.csv --buses buses.csv
```

```bash
npm run pilot-check
```

Tests for these scripts:

```bash
npm run test:tools
```
