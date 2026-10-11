// Makes the local emulators ready for a demo, after `npm run seed`:
//
//   npm run demo-ready
//
// - the demo student gets a bus pass (pass QR, Scan pass, missed-bus help)
// - routes without a guest fare get a demo one (evening seat booking)
// - today's and tomorrow's evening trips are made, as the hourly scheduled
//   function would on a real project (scheduled functions do not run on the
//   emulators)
// - sample public bus and train timings, if the office has entered none
// - every callable function is woken once, so the first scan or SOS of the
//   demo does not wait for a cold start
//
// The seed itself stays plain because the end-to-end tests run it.

process.env.GCLOUD_PROJECT ??= 'demo-whereismybus';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.FIREBASE_DATABASE_EMULATOR_HOST ??= '127.0.0.1:9000';

import { warmFunctions } from './warm-functions.mjs';

// The functions' own code, so evening trips are made exactly as on a real
// project. It sets up firebase-admin from the environment above.
const { db } = await import('../functions/lib/app.js');
const { scheduleEveningTrips } = await import('../functions/lib/bookings.js');

const DEMO_FARES = { 'cbe-gandhipuram': 40, 'cbe-rs-puram': 40, 'pkd-town': 60 };

// The end of the academic year: 31 May, this year or next.
const now = new Date();
const passUntil = `${now.getFullYear() + (now.getMonth() >= 5 ? 1 : 0)}-05-31`;

try {
  await db.doc('users/student-demo').update({ passValid: true, passValidUntil: passUntil });

  const fares = [];
  for (const route of (await db.collection('routes').get()).docs) {
    if (typeof route.get('guestFare') === 'number') continue;
    const fare = DEMO_FARES[route.id] ?? 40;
    await route.ref.update({ guestFare: fare });
    fares.push(`${route.id} ₹${fare}`);
  }

  // Evening trips made before the fares carry no fare; make them again.
  const stale = await db.collection('trips')
    .where('direction', '==', 'fromCampus')
    .where('status', '==', 'scheduled')
    .get();
  for (const trip of stale.docs) {
    if (trip.get('guestFare') == null) await db.recursiveDelete(trip.ref);
  }
  const created = await scheduleEveningTrips(now);

  // Sample public buses and trains for the missed-bus screen, only when the
  // office has entered none. Not real timings: marked as samples.
  const timetable = db.collection('timetable');
  let samples = 0;
  if ((await timetable.limit(1).get()).empty) {
    const note = 'Sample timing: replace with the real one on the dashboard';
    const add = (routeId, mode, name, from, to, departs, direction, fare) =>
      timetable.add({ routeId, mode, name, from, to, departs, direction, note, fare }).then(() => samples++);
    await Promise.all([
      add('cbe-gandhipuram', 'bus', 'Town bus', 'Gandhipuram', 'Ettimadai', '07:10', 'toCampus', 25),
      add('cbe-gandhipuram', 'bus', 'Town bus', 'Gandhipuram', 'Ettimadai', '07:45', 'toCampus', 25),
      add('cbe-gandhipuram', 'train', 'Passenger train', 'Coimbatore Junction', 'Ettimadai', '07:30', 'toCampus', 10),
      add('cbe-gandhipuram', 'bus', 'Town bus', 'Ettimadai', 'Gandhipuram', '17:15', 'fromCampus', 25),
      add('cbe-gandhipuram', 'train', 'Passenger train', 'Ettimadai', 'Coimbatore Junction', '17:40', 'fromCampus', 10),
      add('cbe-rs-puram', 'bus', 'Town bus', 'R.S. Puram', 'Ettimadai', '07:20', 'toCampus', 25),
      add('cbe-rs-puram', 'bus', 'Town bus', 'Ettimadai', 'R.S. Puram', '17:20', 'fromCampus', 25),
      add('pkd-town', 'train', 'Passenger train', 'Palakkad Junction', 'Ettimadai', '06:55', 'toCampus', 15),
      add('pkd-town', 'bus', 'Inter-state bus', 'Palakkad', 'Ettimadai Pirivu', '07:05', 'toCampus', 45),
      add('pkd-town', 'train', 'Passenger train', 'Ettimadai', 'Palakkad Junction', '17:50', 'fromCampus', 15),
    ]);
  }

  console.log('Demo ready:');
  console.log(`  demo student has a bus pass until ${passUntil}`);
  console.log(`  guest fares: ${fares.length ? fares.join(', ') : 'already set'}`);
  console.log(`  evening trips made: ${created.length ? created.join(', ') : 'none needed'}`);
  console.log(`  public bus and train timings: ${samples ? `${samples} samples added` : 'already entered'}`);
  await warmFunctions({ log: (line) => console.log(`  ${line}`) });
  process.exit(0);
} catch (error) {
  if (/ECONNREFUSED|UNAVAILABLE/.test(String(error))) {
    console.error('Could not reach the emulators. Start them with npm run emulators, then npm run seed.');
  } else {
    console.error(error);
  }
  process.exit(1);
}
