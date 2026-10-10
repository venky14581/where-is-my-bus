# Module 13: Testing and pilot

Status: **pilot ready to run; the pilot itself not started, 11 Oct 2026.**
`SPEC.md` was not available; the module plan says "Tested on one real
route". That needs a real Firebase project, an Android phone and the
transport office's real stops, none of which exist yet. What could be done
without them is done and tested. The plan for the rest is
`docs/pilot/pilot-plan.md`.

## What was built

- **Automated tests for every module** (from Module 10 on):
  `npm run test:e2e` checks the server side of Modules 1 to 12 on the
  emulators, alongside the app, functions, rules, dashboard and Python tests.
- **Route data intake.** `data/templates/stops-template.csv` and
  `buses-template.csv` (filled with the placeholder routes as an example)
  for the transport office. `npm run import-routes` checks a filled-in sheet
  and names each problem with its row: times out of order, swapped or
  mistyped coordinates, a gap in numbering, a route not ending at the campus,
  repeated stops, bad seat counts, unknown routes. `--write` puts it in
  `data/base-data.json`.
- **Loading a real project.** `npm run load-base-data -- --project <id>
  --database-url <url> --yes` loads routes, buses and route access with a
  service account; the seed stays emulator-only.
- **Pilot readiness check.** `npm run pilot-check` (emulators, or
  `--project` for a real one) lists what is fine, what to look at and what
  must be fixed: routes and timetables, stops more than 80 m from the road
  (the driver's phone would never record them), buses without a driver or
  with a driver whose phone could not send, the office's access to the live
  map, settings, and learned times made from synthetic trips.
- **Tracking report.** Dashboard → Reports → Tracking: per day, trips run and
  the share of stops recorded (target 95%, shown in red below it), the stops
  missed most often, and every trip with gaps. A stop missed on most trips
  is off the road; scattered gaps mean the phone stopped sending.
- **Arrival-time accuracy.** `ml/evaluate_eta.py` compares, for every pair
  of recorded stops on every trip, the real time with the timetable's and
  the learned estimate, by how far ahead (under 10, 10 to 20, over 20
  minutes): mean error and share within 2 minutes.
- **Hosting.** `firebase.json` serves the built dashboard (with the parents'
  `#/share/` page) from Firebase Hosting, on port 5002 in the emulators.
- **Housekeeping.** Run markers (`functionRuns`) carry an `expireAt` a week
  ahead, so a TTL policy can delete them; parents' links already expire.
- **Pilot documents** in `docs/pilot/`: the plan (setup of a real project,
  the phone checks, two weeks with students, targets, what to do if it goes
  wrong), a one-page driver's guide in English and Tamil, the surveys
  (before, also checking the problem statement; after), and a privacy notice
  draft.

## Done when

| # | Check | Result |
| --- | --- | --- |
| 1 | Every module's automated tests pass. | Pass: 134 app, 42 function, 70 rules, 20 dashboard, 66 e2e, 13 tools, 4 Python tests |
| 2 | The route sheet importer reads the templates back exactly as the current data, and names each kind of mistake with its row. | Pass (tools tests) |
| 3 | The readiness check passes a ready project and catches each problem it looks for. | Pass (tools tests); on the placeholder data it finds 3 routes to fix: Ettimadai Pirivu 326 m, Chandranagar 83 m, Walayar 108 m and the campus stop 82 m from the road |
| 4 | The Tracking report shows gaps by day and stop. | Pass (unit tests; live on the dashboard with two weeks of history: 8 Oct at 94%, Kanjikode missed on 2 of 24 trips) |
| 5 | The accuracy check compares timetable and learned estimates on recorded trips. | Pass (unit test; on synthetic trips: learned 4.7 min against timetable 7.1 min more than 20 minutes ahead, but 1.5 against 0.8 for the next stop or two) |
| 6 | The dashboard and the parents' page work from Hosting. | Pass (hosting emulator: the shared trip showed the live bus) |
| 7 | **Dry run on the real route:** the phone checks P1 to P11 in the pilot plan. | **Not run: needs a real project, the real route and an Android phone** |
| 8 | **Two weeks with students:** tracking 95% of stops, arrival within 2 minutes for 80% of estimates up to 10 minutes ahead, the survey targets. | **Not run** |

## Found while preparing

- **The campus stop is 82 m from the road on every placeholder route**, just
  outside the 80 m in which the driver's phone records a stop. No trip would
  ever record reaching campus, so punctuality and the delay pattern would be
  empty. The real coordinates must put the campus stop where the bus stops.
- **For the next stop or two, the learned times were worse than the
  timetable** on the synthetic trips: the table's half-hour slots do not
  follow a rush that starts mid-slot. Check this on the pilot's real trips
  before switching students to learned times; finer slots, or the timetable
  for short estimates, would fix it.

## Not done

- **App Check** is in the tech stack but not set up. It needs the real
  project's Play Integrity and reCAPTCHA keys; turn it on before opening
  the app beyond the pilot.
- **GitHub Actions** (optional in the stack): the repo has no remote yet.
- **iOS**: the app has the permission texts, but no one has built it for an
  iPhone; the pilot is Android only.
