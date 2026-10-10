# Pilot plan: one route, two weeks

The goal of Module 13: Where Is My Bus used for real on one college bus route
for two weeks, with the checks that could not be run on the emulators done on
real phones, and the numbers to decide whether to go wider.

Everything below the line "Needs the team" has to be done by people: it needs
accounts, phones, the transport office and students. The tools it mentions
are in the repo and tested.

## 1. Choose the route

Pick one route with:

- a driver who is willing and has a recent Android phone (Android 10 or
  later) that can stay on a charger in the bus;
- 20 to 50 day scholars, enough to learn from and few enough to support;
- ideally a known dead zone or two, to see how tracking copes.

The placeholder routes in the repo are not real. Do not pilot on them.

## 2. Set up (about two days)

### Firebase project

1. Create a Firebase project (e.g. `whereismybus-pilot`). Switch it to the
   pay-as-you-go (Blaze) plan: Cloud Functions need it. Set a budget alert
   (say ₹1000 a month); pilot traffic should cost far less.
2. Authentication → Sign-in method: enable **Email/Password**.
3. Firestore: create in **asia-south1** (Mumbai). Realtime Database: create
   the default instance in **asia-southeast1** (Singapore, the nearest).
   Note its address, `https://<project>-default-rtdb.asia-southeast1.firebasedatabase.app`.
4. Razorpay: create a test-mode account and put its test keys in
   `functions/.env` (git-ignored):

   ```
   RAZORPAY_KEY_ID=rzp_test_...
   RAZORPAY_KEY_SECRET=...
   ```

5. Deploy rules, functions and the dashboard (from the repo root):

   ```bash
   firebase deploy --project <project-id> --only firestore,database,functions,hosting
   ```

   Before the hosting part, copy `dashboard/.env.example` to
   `dashboard/.env.local` and fill it in from Project settings → Your apps →
   Web app. The dashboard and the parents' page are then at
   `https://<project-id>.web.app`.
6. Housekeeping: delete old run markers and expired parent links
   automatically (Firestore → TTL policies, or):

   ```bash
   gcloud firestore fields ttls update expireAt --collection-group=functionRuns --enable-ttl --project <project-id>
   gcloud firestore fields ttls update expiresAt --collection-group=shares --enable-ttl --project <project-id>
   ```

### Office account

The seed script only works on the emulators. For the real project, once:

1. Authentication → Users → Add user: the transport office's email and a
   strong password.
2. Firestore → `users/<that uid>`: `{ name: "Transport Office", role: "office", email: "<email>" }`.
3. Realtime Database → `officeUids/<that uid>`: `true` (lets the office see
   live positions).

### Route data

1. The transport office fills in `data/templates/stops-template.csv` and
   `buses-template.csv` for the pilot route (a spreadsheet saved as CSV; the
   templates show the format). **Stand at each stop** and take the
   coordinates where the bus actually stops, on the road: the driver's phone
   records a stop only within 80 m of it.
2. Check and import:

   ```bash
   npm run import-routes -- --stops stops.csv --buses buses.csv
   npm run import-routes -- --stops stops.csv --buses buses.csv --write
   npm run build-paths
   ```

3. Sign in to the dashboard and add the pilot driver (Drivers → Add), with
   the ID used in `buses.csv`. Give the driver their PIN in person.
4. Load the route and bus, with a service account key for the project
   (Project settings → Service accounts → Generate new private key; keep it
   out of the repo):

   ```bash
   set GOOGLE_APPLICATION_CREDENTIALS=C:\keys\whereismybus-pilot.json
   npm run load-base-data -- --project <project-id> --database-url <rtdb-url> --yes
   ```

5. On the dashboard: set the guest fare and booking window, the speed limit,
   and which routes accept riders from the pilot route (route access).
6. **Do not load the synthetic learned times** (`npm run import-ml`) into
   the real project. Students should see the timetable until real trips are
   learned from (step 6).
7. Check everything:

   ```bash
   npm run pilot-check -- --project <project-id> --database-url <rtdb-url>
   ```

   It must report nothing to fix. On the placeholder data it finds 3 routes
   with stops too far from the road, including the campus stop on every
   route (82 m): with real data, put the campus stop where the bus stops.

### App

1. Install Android Studio (it brings the Android SDK), then `flutter doctor`.
2. In `app/`: `flutterfire configure --project <project-id>` (the app stops
   using the emulators by itself).
3. Build:

   ```bash
   flutter build apk --release --dart-define=SHARE_BASE_URL=https://<project-id>.web.app
   ```

4. Driver's phone: install, sign in as the driver, choose the language,
   allow location **while using the app** and notifications; in the phone's
   battery settings set the app to **Unrestricted** (not optimised). Keep it
   on a charger in the bus.
5. Students: share the APK (or an internal-testing track on Google Play).
   They sign up with their college email.

## 3. Phone checks before students (one dry run, no riders)

These are the Done-when checks the emulators could not do. Two team members
ride along: one with the driver's phone, one with a student's.

| # | Module | Check | Pass when |
| --- | --- | --- | --- |
| P1 | 3 | Start Trip, lock the screen, ride 5 minutes | `live/<bus>` keeps updating (Realtime Database console, or the dashboard's live map), and the notification with the bus number and route stays |
| P2 | 3 | Ride through a known dead zone | The bus shows weak signal / offline on the student's phone, then catches up; the stop times inside the dead zone are recorded when the signal returns |
| P3 | 6 | Student app closed, then open | "Your bus has started", "is 2 stops away" and a Running late report arrive both ways |
| P4 | 8 | Driver scans the student's pass from another phone's screen | Boarded; scanning again says already boarded |
| P5 | 10 | Book an evening seat, pay with a Razorpay test card, show the ticket | Seat booked, ticket scans once |
| P6 | 11 | Student sets a 5-minute walk | "Leave home by" shows and the "Time to leave" notification arrives once |
| P7 | 12 | Set the speed limit to 20 km/h on the dashboard, drive normally for a minute | One Overspeeding alert on the dashboard; set the limit back |
| P8 | 12 | Take a short detour off the route (on the dry run only) | One Off the route alert after a minute away |
| P9 | 12 | Press SOS on the driver's phone (tell the office first) | The dashboard shows the red banner with the bus's position |
| P10 | 12 | Share my trip; open the link on a phone that is not signed in | The bus moves on the map; the link stops working after End Trip |
| P11 | 13 | Dashboard → Reports → Tracking for the dry run | Every stop recorded, including the campus |

Write the results in the table in `docs/modules/module-13-testing-and-pilot.md`.

## 4. Two weeks with students

- **Before day 1:** a 15-minute talk on the bus or in class: what the app
  does, that it shows the bus and never the student, the privacy notice
  (`docs/pilot/privacy-notice.md`), and the timetable stays valid if the app
  fails. Give the driver the one-page guide (`docs/pilot/driver-guide.md`).
- **Every day (office, 5 minutes):** Reports → Tracking for yesterday (target
  95% of stops recorded); Safety alerts; any messages from students. If a
  trip has gaps, ask the driver what happened that morning.
- **End of week 1:** export the trips and check arrival-time accuracy:

  ```bash
  npm run export-trips -- --project <project-id> --out ../ml/data
  ml/.venv/Scripts/python ml/evaluate_eta.py --learned none
  ```

- **End of week 2:** export again, train on the two weeks (`ml/train.py`),
  check the error on held-out days, and load the learned times only if they
  beat the timetable (Module 11). On synthetic trips the learned times beat
  the timetable for estimates more than 10 minutes ahead but not for the
  next stop or two; check whether real trips show the same before switching.
  Run the survey (`docs/pilot/survey.md`).

## 5. What success looks like

| Measure | Target | From |
| --- | --- | --- |
| Stops recorded by the driver's phone | 95% or more, every day | Reports → Tracking |
| Arrival time within 2 minutes, for estimates up to 10 minutes ahead | 80% or more | `ml/evaluate_eta.py` |
| Students on the route who signed up | Half or more | Firebase Authentication |
| Students who used it at least 3 days a week | Half of those signed up | Survey |
| Days the driver forgot or could not start a trip | At most 1 | Reports → Tracking (trips per day) |
| SOS or safety alerts not seen by the office within 10 minutes | None | Safety alerts |
| Students who would recommend it | 70% or more | Survey |

If tracking is below 95%, look at which stops are missed (Tracking → Stops
missed most often): the same stop every day means it is off the road; random
gaps mean the phone is stopping (battery settings, screen-off).

## 6. If something goes wrong

- The paper timetable stays in force throughout; the app only adds to it.
- If the driver's phone fails, the trip is not tracked that day; post an
  announcement from the dashboard so students know.
- To stop the pilot: post an announcement, and in Firebase Authentication
  disable the driver's account. Nothing else depends on the app.

## Open questions this pilot should answer

From `CLAUDE.md`: whether guests should pay or ride free; booking closing 20
or 30 minutes before; which other towns are served; the student email
domain; and whether the problem statement matches what day scholars say
(the survey asks).
