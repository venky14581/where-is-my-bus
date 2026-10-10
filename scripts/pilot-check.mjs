// Before a pilot day: is everything in place? Reads the project's data and
// lists what is fine, what to look at, and what must be fixed.
//
//   npm run pilot-check                         the local emulators
//   npm run pilot-check -- --project <id> --database-url <url>
//                                               a real project, with credentials
//                                               from GOOGLE_APPLICATION_CREDENTIALS
//
// Exits with 1 if anything must be fixed.

import { initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { getFirestore } from 'firebase-admin/firestore';
import { pilotChecks } from './pilot-checks.mjs';

const args = process.argv.slice(2);
const i = args.indexOf('--project');
const projectId = i >= 0 ? args[i + 1] : 'demo-whereismybus';
if (projectId.startsWith('demo-')) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  process.env.FIREBASE_DATABASE_EMULATOR_HOST ??= '127.0.0.1:9000';
}
// A database outside the US has a regional address; pass it with --database-url
// (Firebase console → Realtime Database), e.g.
// https://<project>-default-rtdb.asia-southeast1.firebasedatabase.app
const d = args.indexOf('--database-url');
const databaseURL = d >= 0 ? args[d + 1] : `https://${projectId}-default-rtdb.firebaseio.com`;
const app = initializeApp({ projectId, databaseURL });
const db = getFirestore(app);
const rtdb = getDatabase(app);

const all = async (name) => (await db.collection(name).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
const byId = (rows) => Object.fromEntries(rows.map((r) => [r.id, r]));

const [routes, buses, users, settings, segmentTimes, routeAccess, busDrivers, officeUids] = await Promise.all([
  all('routes'),
  all('buses'),
  db.collection('users').where('role', 'in', ['driver', 'office']).get().then((s) => s.docs.map((d) => ({ id: d.id, ...d.data() }))),
  all('settings').then(byId),
  all('segmentTimes').then(byId),
  all('routeAccess').then(byId),
  rtdb.ref('busDrivers').get().then((s) => s.val() ?? {}),
  rtdb.ref('officeUids').get().then((s) => s.val() ?? {}),
]);

const findings = pilotChecks({ routes, buses, users, busDrivers, officeUids, settings, segmentTimes, routeAccess });
const MARK = { ok: '  ok  ', warn: ' look ', fail: ' FIX  ' };
// Grouped by area, in the order the areas first come up.
for (const area of new Set(findings.map((f) => f.area))) {
  console.log(`\n${area}`);
  for (const f of findings.filter((x) => x.area === area)) console.log(`${MARK[f.level]} ${f.message}`);
}
const failures = findings.filter((f) => f.level === 'fail').length;
const warnings = findings.filter((f) => f.level === 'warn').length;
console.log(`\n${projectId}: ${failures} to fix, ${warnings} to look at.`);
process.exit(failures ? 1 : 0);
