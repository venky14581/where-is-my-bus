# Where Is My Bus

Live college bus tracking for Amrita Coimbatore day scholars. The driver's
phone is the only tracker. Project knowledge, decisions and the module plan
are in [CLAUDE.md](CLAUDE.md); progress per module is in [docs/modules](docs/modules).

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

## Connecting a real Firebase project

Not done yet. When the team has a project: run `flutterfire configure` in
`app/` (this overwrites `lib/firebase_options.dart` and the app stops using the
emulators by itself), fill in `dashboard/.env.local`, and deploy the rules with
`firebase deploy --only firestore,database,functions`. Cloud Functions need
the pay-as-you-go plan.
