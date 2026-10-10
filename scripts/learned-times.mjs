// Loads the arrival-time model's output (ml/out/segment_times.json, made by
// ml/train.py) into Firestore as segmentTimes/{routeId}. Used by
// seed-emulators.mjs and `npm run import-ml`; works with any Admin SDK
// Firestore instance.

import { readFile } from 'node:fs/promises';
import { FieldValue } from 'firebase-admin/firestore';

const OUTPUT = new URL('../ml/out/segment_times.json', import.meta.url);

/** Returns the number of routes loaded, or 0 when there is no model output. */
export async function importLearnedTimes(db) {
  let learned;
  try {
    learned = JSON.parse(await readFile(OUTPUT, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return 0;
    throw error;
  }
  const batch = db.batch();
  for (const [routeId, entry] of Object.entries(learned.routes)) {
    batch.set(db.doc(`segmentTimes/${routeId}`), {
      slotMinutes: learned.slotMinutes,
      toCampus: entry.toCampus ?? null,
      fromCampus: entry.fromCampus ?? null,
      delayByWeekday: entry.delayByWeekday ?? {},
      // Shown nowhere to students, but kept so nobody mistakes synthetic
      // numbers for a route's real behaviour.
      source: learned.source,
      trainedOn: { trips: learned.trips, from: learned.from, to: learned.to },
      evaluation: learned.evaluation,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return Object.keys(learned.routes).length;
}

// npm run import-ml: into the local emulators only.
if (import.meta.url === `file:///${process.argv[1]?.replaceAll('\\', '/')}` || process.argv[1]?.endsWith('learned-times.mjs')) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  const { initializeApp } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  const count = await importLearnedTimes(getFirestore(initializeApp({ projectId: 'demo-whereismybus' })));
  console.log(count ? `Loaded learned times for ${count} routes.` : 'No ml/out/segment_times.json. Run ml/train.py first.');
}
