// Posts a transport office announcement in the local emulators, until the
// dashboard screen for it exists (Module 7).
//
//   npm run announce -- "Holiday on Monday" "No buses run on Monday."
//   npm run announce -- "Route change" "Bus skips Town Hall today." cbe-gandhipuram

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const [title, body = '', routeId = null] = process.argv.slice(2);
if (!title) {
  console.error('Usage: npm run announce -- "<title>" "<body>" [routeId]');
  process.exit(1);
}

const db = getFirestore(initializeApp({ projectId: 'demo-whereismybus' }));
const ref = await db.collection('announcements').add({
  routeId,
  title,
  body,
  createdAt: FieldValue.serverTimestamp(),
  createdBy: 'office-demo',
});
console.log(`Announcement ${ref.id} posted to ${routeId ?? 'all routes'}.`);
process.exit(0);
