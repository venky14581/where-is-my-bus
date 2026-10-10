// Realtime Database rules cannot read Firestore, so they check who may write
// live/{busId} against busDrivers/{busId}. This keeps that mirror in step with
// buses/{busId}.driverId, whoever changes it: the dashboard, the import
// script or the Firebase console.

import { getDatabaseWithUrl } from 'firebase-admin/database';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import { app } from './app.js';

/**
 * The default database instance, which is where database.rules.json applies.
 * In production FIREBASE_CONFIG names it. The emulator instead names a
 * namespace after the project, which has no rules and that nothing reads,
 * so there the default instance's name is built explicitly.
 */
export function databaseUrl(env: NodeJS.ProcessEnv = process.env): string {
  const config = JSON.parse(env.FIREBASE_CONFIG ?? '{}') as { databaseURL?: string; projectId?: string };
  const project = config.projectId ?? env.GCLOUD_PROJECT;
  if (env.FUNCTIONS_EMULATOR !== 'true' && config.databaseURL) return config.databaseURL;
  return `https://${project}-default-rtdb.firebaseio.com`;
}

export const mirrorBusDriver = onDocumentWritten('buses/{busId}', async (event) => {
  const driverId = event.data?.after.exists ? event.data.after.get('driverId') : null;
  const ref = getDatabaseWithUrl(databaseUrl(), app).ref(`busDrivers/${event.params.busId}`);
  if (typeof driverId === 'string' && driverId.length > 0) {
    await ref.set(driverId);
  } else {
    await ref.remove();
  }
});
