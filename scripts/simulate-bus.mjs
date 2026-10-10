// Moves a bus along its route in the local emulators, as if a driver were
// sharing their position. For trying the student map without a phone.
//
//   npm run simulate-bus             # bus-01, morning direction
//   npm run simulate-bus -- bus-03   # another bus
//
// Ctrl+C leaves the bus marked offline, like a phone losing signal. At the
// end of the route the bus is marked ended.

process.env.FIREBASE_DATABASE_EMULATOR_HOST ??= '127.0.0.1:9000';

import { readFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { getDatabase, ServerValue } from 'firebase-admin/database';

const PROJECT_ID = 'demo-whereismybus';
const busId = process.argv[2] ?? 'bus-01';
const TICK_MS = 3000;
const SPEED_MPS = 11; // about 40 km/h
const SPEEDUP = 5; // so a 25 km route takes minutes, not most of an hour

const readJson = async (name) => JSON.parse(await readFile(new URL(`../data/${name}`, import.meta.url), 'utf8'));
const base = await readJson('base-data.json');
const paths = await readJson('route-paths.json');
const bus = base.buses.find((b) => b.id === busId);
if (!bus) throw new Error(`No bus ${busId} in data/base-data.json`);

const app = initializeApp({ projectId: PROJECT_ID, databaseURL: `https://${PROJECT_ID}-default-rtdb.firebaseio.com` });
const live = getDatabase(app).ref(`live/${busId}`);

function decodePolyline(encoded) {
  const points = [];
  let index = 0, lat = 0, lng = 0;
  const next = () => {
    let result = 0, shift = 0, byte;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return result & 1 ? -(result >> 1) - 1 : result >> 1;
  };
  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.push([lat / 1e5, lng / 1e5]);
  }
  return points;
}

function metres([lat1, lng1], [lat2, lng2]) {
  const r = 6371000, rad = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lng2 - lng1) * rad) / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(a));
}

const path = decodePolyline(paths[bus.routeId].polyline);
const tripId = `${new Date().toISOString().slice(0, 10)}_${busId}_toCampus_simulated`;
let segment = 0, along = 0;

function position() {
  if (segment >= path.length - 1) return path.at(-1);
  const [a, b] = [path[segment], path[segment + 1]];
  const length = metres(a, b);
  const t = length === 0 ? 0 : along / length;
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}

function advance(m) {
  while (segment < path.length - 1) {
    const remaining = metres(path[segment], path[segment + 1]) - along;
    if (m < remaining) { along += m; return; }
    m -= remaining; segment++; along = 0;
  }
}

async function tick() {
  const [lat, lng] = position();
  await live.set({ lat, lng, speed: SPEED_MPS, heading: 0, accuracy: 5, updatedAt: ServerValue.TIMESTAMP, tripId, status: 'running' });
  if (segment >= path.length - 1) {
    await live.update({ status: 'ended', updatedAt: ServerValue.TIMESTAMP });
    console.log(`${busId} reached the end of ${bus.routeId}; marked ended.`);
    process.exit(0);
  }
  advance(SPEED_MPS * (TICK_MS / 1000) * SPEEDUP);
}

process.on('SIGINT', async () => {
  await live.update({ status: 'offline' });
  console.log(`\n${busId} marked offline.`);
  process.exit(0);
});

console.log(`Driving ${busId} along ${bus.routeId} (${path.length} points). Ctrl+C to drop it offline.`);
await tick();
setInterval(() => tick().catch((e) => { console.error(e); process.exit(1); }), TICK_MS);
