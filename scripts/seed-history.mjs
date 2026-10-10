// Fills the local emulators with past trips so the office reports and trip
// history have something to show: two weeks of morning and evening trips
// for every bus, with stop times, boardings, guest bookings and a few
// safety alerts. Everything it writes is marked `synthetic: true`.
//
//   npm run seed                      (first)
//   npm run seed-history              (last 14 days before today)
//   npm run seed-history -- --days 30
//
// Emulators only. Real history comes from real trips.

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';

import { readFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'demo-whereismybus';
if (!PROJECT_ID.startsWith('demo-')) throw new Error('History is only made up on the emulators.');

const args = process.argv.slice(2);
const days = Number(args[args.indexOf('--days') + 1]) || 14;
const db = getFirestore(initializeApp({ projectId: PROJECT_ID }));
const base = JSON.parse(await readFile(new URL('../data/base-data.json', import.meta.url), 'utf8'));

// A fixed seed, so every run makes the same history.
let seed = 20261012;
const random = () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const normal = () => Math.sqrt(-2 * Math.log(random() || 1e-9)) * Math.cos(2 * Math.PI * random());
const count = (mean) => Math.max(0, Math.round(mean + normal() * Math.sqrt(mean)));

const campusDate = (d) => d.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
const at = (date, minutes) => new Date(Date.parse(`${date}T00:00:00+05:30`) + minutes * 60_000);
const minutesOf = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3));
const weekday = (date) => new Date(`${date}T12:00:00Z`).getUTCDay(); // 0 = Sunday

// Mondays and Fridays run late, Saturdays early.
const LATE_BY_DAY = { 1: 5, 2: 1, 3: 0, 4: 2, 5: 7, 6: -1 };
// Riders expected at each stop of a route, first stop to the last before campus.
// One stop is nearly unused and the Palakkad bus is nearly full, so the
// route suggestions have something to say.
const RIDERS = {
  'cbe-gandhipuram': { gandhipuram: 10, 'town-hall': 7, ukkadam: 8, kuniyamuthur: 6, madukkarai: 5, 'ettimadai-pirivu': 0.3 },
  'cbe-rs-puram': { 'rs-puram': 9, selvapuram: 7, 'kovaipudur-pirivu': 5, 'ettimadai-pirivu': 2 },
  'pkd-town': { 'palakkad-stadium': 19, chandranagar: 11, kanjikode: 9, walayar: 7 },
};
const GUEST_FARE = { 'cbe-gandhipuram': 40, 'cbe-rs-puram': 30 };

const today = campusDate(new Date());
let trips = 0;
let riders = 0;
let guests = 0;
let alerts = 0;

for (let back = days; back >= 1; back--) {
  const date = campusDate(new Date(Date.parse(`${today}T12:00:00+05:30`) - back * 86_400_000));
  const day = weekday(date);
  if (day === 0) continue; // no buses on Sundays
  for (const bus of base.buses) {
    const route = base.routes.find((r) => r.id === bus.routeId);
    const driverUid = bus.driver ? `driver-${bus.driver}` : null;
    const stops = route.stops;
    const lateAtCampus = LATE_BY_DAY[day] + normal() * 3;
    const batch = db.batch();

    // Morning: delay grows along the route.
    const morning = `${date}_${bus.id}_toCampus`;
    const first = minutesOf(stops[0].scheduledTime);
    batch.set(db.doc(`trips/${morning}`), {
      busId: bus.id, routeId: route.id, driverId: driverUid, date, direction: 'toCampus', status: 'ended',
      startedAt: Timestamp.fromDate(at(date, first - 5)), endedAt: Timestamp.fromDate(at(date, minutesOf(stops.at(-1).scheduledTime) + lateAtCampus + 2)),
      passHolders: Object.values(RIDERS[route.id]).reduce((a, b) => a + b, 0) | 0, altHeld: 0, synthetic: true,
    });
    stops.forEach((stop, i) => {
      const minutes = minutesOf(stop.scheduledTime) + lateAtCampus * (i / (stops.length - 1)) + normal() * 0.5;
      // Now and then the phone misses a stop (a moment without signal), for the Tracking report.
      if (random() >= 0.04) {
        batch.set(db.doc(`trips/${morning}/stopTimes/${stop.id}`), {
          stopId: stop.id, arrivedAt: Timestamp.fromDate(at(date, minutes)), recordedAt: Timestamp.fromDate(at(date, minutes)),
        });
      }
      for (let n = count(RIDERS[route.id][stop.id] ?? 0); n > 0; n--) {
        const uid = `history-${route.id}-${stop.id}-${n}`;
        batch.set(db.doc(`trips/${morning}/boardings/${uid}`), {
          type: random() < 0.05 ? 'alternate' : 'pass', name: `Rider ${n}`, stopId: stop.id, at: Timestamp.fromDate(at(date, minutes)), synthetic: true,
        });
        riders++;
      }
    });

    // Evening: from campus out along the route, with guests on two routes.
    const evening = `${date}_${bus.id}_fromCampus`;
    const departs = 16 * 60 + 30 + Math.max(0, normal() * 3);
    const reversed = [...stops].reverse();
    const scheduledGap = (i) => Math.abs(minutesOf(reversed[i].scheduledTime) - minutesOf(reversed[0].scheduledTime));
    batch.set(db.doc(`trips/${evening}`), {
      busId: bus.id, routeId: route.id, driverId: driverUid, date, direction: 'fromCampus', status: 'ended',
      startedAt: Timestamp.fromDate(at(date, departs)), endedAt: Timestamp.fromDate(at(date, departs + scheduledGap(stops.length - 1) * 1.1 + 2)),
      synthetic: true,
    });
    reversed.forEach((stop, i) => {
      batch.set(db.doc(`trips/${evening}/stopTimes/${stop.id}`), {
        stopId: stop.id, arrivedAt: Timestamp.fromDate(at(date, departs + scheduledGap(i) * 1.1)), recordedAt: Timestamp.fromDate(at(date, departs + scheduledGap(i) * 1.1)),
      });
    });
    const fare = GUEST_FARE[route.id];
    if (fare) {
      for (let n = count(3); n > 0; n--) {
        const uid = `history-guest-${n}`;
        const drop = stops[Math.floor(random() * (stops.length - 1))].id;
        const showed = random() < 0.85;
        batch.set(db.doc(`bookings/${evening}_${uid}`), {
          tripId: evening, uid, name: `Guest ${n}`, routeId: route.id, busId: bus.id, date,
          departsAt: Timestamp.fromDate(at(date, 16 * 60 + 30)), stopId: drop, fare, status: showed ? 'used' : 'confirmed',
          payment: { mode: 'demo' }, synthetic: true,
        });
        if (showed) {
          batch.set(db.doc(`trips/${evening}/boardings/${uid}`), { type: 'guest', name: `Guest ${n}`, stopId: stops.at(-1).id, at: Timestamp.fromDate(at(date, departs)), synthetic: true });
        }
        guests++;
      }
    }

    // Now and then the phone noticed something.
    if (random() < 0.12) {
      const stop = stops[1 + Math.floor(random() * (stops.length - 2))];
      const speeding = random() < 0.6;
      batch.set(db.doc(`safetyAlerts/${morning}_history`), {
        type: speeding ? 'overspeed' : 'offRoute', tripId: morning, busId: bus.id, busNumber: bus.number, routeId: route.id, routeName: route.name,
        driverName: '', fromUid: driverUid, fromRole: 'driver', fromName: '', lat: stop.lat, lng: stop.lng,
        details: speeding ? { speedKmh: 66 + Math.round(random() * 10), limitKmh: 60 } : { distanceM: 350 + Math.round(random() * 300) },
        status: 'acknowledged', at: Timestamp.fromDate(at(date, minutesOf(stop.scheduledTime))),
        acknowledgedBy: 'office-demo', acknowledgedAt: Timestamp.fromDate(at(date, minutesOf(stop.scheduledTime) + 4)), synthetic: true,
      });
      alerts++;
    }
    await batch.commit();
    trips += 2;
  }
}

console.log(`Made up ${trips} past trips over ${days} days: ${riders} morning riders, ${guests} guest bookings, ${alerts} safety alerts.`);
process.exit(0);
