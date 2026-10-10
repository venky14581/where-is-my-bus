// Loads data/base-data.json and the road paths into a real Firebase project,
// for the pilot. Overwrites those routes, buses and route access; anything
// else (students, trips, other routes) is left alone. Drivers named in
// base-data.json must exist first (add them on the dashboard).
//
//   npm run import-routes -- --stops stops.csv --buses buses.csv --write
//   npm run build-paths
//   npm run load-base-data -- --project <project-id> --database-url <url> --yes
//
// Credentials: GOOGLE_APPLICATION_CREDENTIALS pointing at a service account
// key for the project (Firebase console → Project settings → Service accounts).
// The emulators are loaded by `npm run seed` instead.

import { initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { getFirestore } from 'firebase-admin/firestore';
import { importBaseData } from './base-data.mjs';

const args = process.argv.slice(2);
const i = args.indexOf('--project');
const projectId = i >= 0 ? args[i + 1] : undefined;
if (!projectId || projectId.startsWith('demo-')) {
  console.error('Usage: npm run load-base-data -- --project <real-project-id> --yes   (emulators: npm run seed)');
  process.exit(2);
}
if (!args.includes('--yes')) {
  console.error(`This overwrites the routes, buses and route access in ${projectId}. Run again with --yes to go ahead.`);
  process.exit(2);
}

// A database outside the US has a regional address; pass it with --database-url
// (Firebase console → Realtime Database), e.g.
// https://<project>-default-rtdb.asia-southeast1.firebasedatabase.app
const d = args.indexOf('--database-url');
const databaseURL = d >= 0 ? args[d + 1] : `https://${projectId}-default-rtdb.firebaseio.com`;
const app = initializeApp({ projectId, databaseURL });
const counts = await importBaseData(getFirestore(app), getDatabase(app));
console.log(`Loaded ${counts.routes} routes and ${counts.buses} buses into ${projectId}. Next: npm run pilot-check -- --project ${projectId}`);
process.exit(0);
