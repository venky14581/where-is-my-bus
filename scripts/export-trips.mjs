// Exports recorded trips for the arrival-time model: ended trips and their
// stop times, in the format ml/trips.py reads (see there).
//
//   npm run export-trips                 the local emulators, into ml/data/
//   npm run export-trips -- --project <id> --out <dir>
//                                        a real project, with credentials from
//                                        GOOGLE_APPLICATION_CREDENTIALS
//
// Only bus times are exported: no student, booking or pass data.

import { mkdir, writeFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const projectId = option('project', 'demo-whereismybus');
const outDir = new URL(`${option('out', '../ml/data')}/`, new URL('.', import.meta.url));
if (projectId.startsWith('demo-')) process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';

const db = getFirestore(initializeApp({ projectId }));

const routes = (await db.collection('routes').get()).docs.map((r) => ({ id: r.id, data: r.data() }));
const buses = (await db.collection('buses').get()).docs;
const routesOut = routes.map((r) => ({
  id: r.id,
  buses: buses.filter((b) => b.get('routeId') === r.id).map((b) => b.id),
  stops: (r.data.stops ?? []).map((s) => ({ id: s.id, scheduledTime: s.scheduledTime })),
}));

const csv = ['trip_id,route_id,date,direction,stop_id,arrived_at'];
let trips = 0;
for (const trip of (await db.collection('trips').where('status', '==', 'ended').get()).docs) {
  const { routeId, date, direction } = trip.data();
  if (typeof routeId !== 'string' || typeof date !== 'string') continue;
  const times = await trip.ref.collection('stopTimes').get();
  if (times.size < 2) continue;
  trips++;
  for (const t of times.docs) {
    const at = t.get('arrivedAt')?.toDate?.();
    if (at) csv.push([trip.id, routeId, date, direction, t.id, at.toISOString()].join(','));
  }
}

await mkdir(outDir, { recursive: true });
await writeFile(new URL('routes.json', outDir), JSON.stringify(routesOut, null, 2));
await writeFile(new URL('stop_times.csv', outDir), `${csv.join('\n')}\n`);
await writeFile(new URL('SOURCE', outDir), 'recorded\n');
console.log(`Exported ${trips} ended trips (${csv.length - 1} stop times) from ${projectId} to ${outDir.pathname}`);
process.exit(0);
