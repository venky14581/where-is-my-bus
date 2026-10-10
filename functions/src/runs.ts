import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from './app.js';

/** Long past any retry; a TTL policy on expireAt deletes the marker then. */
const KEEP_MS = 7 * 24 * 3600_000;

/**
 * Triggers are delivered at least once, so the same trip start or report can
 * arrive twice. Claims [key] for this run; false means another run already
 * handled it. Keyed by what happened, not by event ID, so it holds however
 * the duplicate arrives.
 */
export async function claim(key: string): Promise<boolean> {
  try {
    await db.doc(`functionRuns/${key}`).create({
      at: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + KEEP_MS),
    });
    return true;
  } catch (e) {
    if ((e as { code?: number }).code === 6) return false; // ALREADY_EXISTS
    throw e;
  }
}
