# Where Is My Bus

Live college bus tracking for Amrita Coimbatore day scholars. The driver's
phone is the only tracker. Project knowledge, decisions and the module plan
are in [CLAUDE.md](CLAUDE.md); progress per module is in [docs/modules](docs/modules).

| Folder | What |
| --- | --- |
| `app/` | Flutter app: students and drivers (Android, iOS; web for development) |
| `dashboard/` | React dashboard for the transport office |
| `firestore.rules`, `database.rules.json` | Security rules |
| `scripts/seed-emulators.mjs` | Demo accounts for the local emulators |
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
cd app && flutter pub get
```

## Run everything locally

Nothing here touches a real Firebase project: the app and dashboard use the
`demo-whereismybus` project, which only exists on the emulators.

1. Start the emulators and leave them running (UI at http://localhost:4000):

   ```bash
   npm run emulators
   ```

2. In a second terminal, create the demo accounts (re-run after every emulator
   restart, since the emulators start empty):

   ```bash
   npm run seed
   ```

   The test passwords and driver PINs are in `scripts/seed-emulators.mjs`.

3. Student and driver app in Chrome:

   ```bash
   cd app && flutter run -d chrome
   ```

   Use `flutter run` (a debug build) for web. A release web build pointed at
   the emulators loses the signed-in session on page reload, because Firebase
   Auth checks the saved user before the app can redirect it to the emulator.
   Android, iOS and real projects are not affected.

4. Office dashboard at http://localhost:5173:

   ```bash
   npm --prefix dashboard run dev
   ```

Verification emails are not sent anywhere. Open the link from the Auth tab of
the emulator UI (http://localhost:4000/auth), then tap **I've verified**.

### On an Android phone

The app finds the emulators at `10.0.2.2` on the Android emulator. For a
physical phone on the same Wi-Fi, add `"host": "0.0.0.0"` to the `auth` and
`firestore` entries in `firebase.json`, then run:

```bash
cd app && flutter run --dart-define=EMULATOR_HOST=192.168.1.20
```

(replace the address with your computer's LAN IP).

## Tests

```bash
cd app && flutter test
```

```bash
npm run test:rules
```

## Connecting a real Firebase project

Not done yet. When the team has a project: run `flutterfire configure` in
`app/` (this overwrites `lib/firebase_options.dart` and the app stops using the
emulators by itself), fill in `dashboard/.env.local`, and deploy the rules with
`firebase deploy --only firestore:rules,database`. Cloud Functions (later
modules) need the pay-as-you-go plan.
