# Module 1: Setup and login

Status: **done**, 10 Oct 2026. Tested on Flutter web and the Firebase
emulators; not yet run on an Android or iOS phone (no Android SDK on the build
machine).

`SPEC.md` was not available, so the Done-when test below was written for this
module. Confirm it, or replace it with the one from `SPEC.md` if that file
turns up.

## What was built

- Repository layout from the project spec: `app/`, `dashboard/`, rules and
  `firebase.json` at the root. `functions/` and `ml/` arrive with the modules
  that need them.
- Firebase Emulator Suite setup (Auth, Firestore, Realtime Database) on the
  `demo-whereismybus` project, plus a seed script with demo accounts.
- Flutter app (Riverpod, go_router, Hive, Tamil and English):
  - Welcome screen: choose student or driver, switch language.
  - Student: sign up with a college email, verify the email, sign in, reset
    password, finish setup if the profile is missing.
  - Driver: sign in with driver ID and 6-digit PIN, choose language at first
    login, driver home with the large (not yet active) Start Trip button.
  - One redirect function decides which screens each role may open.
- React dashboard: office-only sign-in and an empty signed-in shell.
- Security rules for `users/{uid}`; every other path is closed.

## Decisions made in this module

| Decision | Why |
| --- | --- |
| Students: email and password, `@cb.students.amrita.edu` only, verified email required | College-only login without paid features. Checked in the app and in the rules. |
| Drivers: ID `DRV001` + PIN is signed in as `drv001@drivers.whereismybus.invalid` | Firebase's free plan has no phone OTP or Cloud Functions. `.invalid` can never receive mail, so a password-reset email for a driver account reaches nobody. |
| PIN is 6 digits | Firebase's minimum password length is 6. |
| Only the office creates driver and office profiles | Rules refuse a self-made profile with any role but `student`, or with `passValid: true`. |
| Office signs in on the dashboard, not the app | The app shows "office accounts use the web dashboard" if one ever reaches it. |
| Emulators by default | `demo-` projects never reach real Firebase, so nobody needs credentials to develop. |

## Done when

With `npm run emulators` and `npm run seed`:

| # | Check | Result |
| --- | --- | --- |
| 1 | A new student with a `@cb.students.amrita.edu` email creates an account, is held on "Verify your email" until the link is opened, then lands on the student home with their name. | Pass (web, live) |
| 2 | A non-college email is refused by the app, and by the security rules when the app is bypassed. | Pass (widget test, rules test) |
| 3 | Driver `DRV001` with the right PIN signs in, chooses Tamil at first login, sees the driver home in Tamil, and the choice is saved on the profile. A wrong PIN shows "Driver ID or PIN is wrong". | Pass (web, live) |
| 4 | Driver `DRV009` (account but no profile) is told to ask the transport office. | Pass (web, live) |
| 5 | The office account signs in to the dashboard; a student account is refused there. | Pass (web, live) |
| 6 | A signed-in student cannot open driver screens and the other way round. Nobody can give themselves a role or a valid pass. | Pass (live, redirect tests, rules tests) |
| 7 | Sign out works for all three roles. | Pass (web, live) |
| 8 | `flutter test` and `npm run test:rules` pass. | Pass: 26 app tests, 19 rules tests |

## Known gaps

- Not run on a phone yet. Install Android Studio, then run check 3 on a real
  Android phone before starting Module 3, which needs one anyway.
- Release web builds lose the session on reload when pointed at the emulators
  (see the README). Debug web, mobile and real projects are fine.
- The Tamil text was written without a native speaker's review. Have someone
  check `app/lib/l10n/app_ta.arb`, especially the driver screens.
- No real Firebase project yet; see "Connecting a real Firebase project" in the
  README.
