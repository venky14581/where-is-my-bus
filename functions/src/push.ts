import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { Messaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

import type { AlertKind } from './audience.js';
import { render, type Language, type MessageParams } from './messages.js';

export interface Recipient {
  uid: string;
  language: Language;
}

const STALE_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Pushes one alert to each recipient's devices, in their language.
 *
 * On the emulators FCM cannot deliver anything (demo projects have no real
 * credentials), so each message is written to `pushLog` instead, where tests
 * and developers can see exactly who would have been told what.
 */
export async function deliver(options: {
  db: Firestore;
  messaging: () => Messaging;
  recipients: Recipient[];
  kind: AlertKind;
  params: MessageParams;
  data?: Record<string, string>;
}): Promise<void> {
  const { db, recipients, kind, params } = options;
  if (recipients.length === 0) return;
  const data = { kind, ...(options.data ?? {}) };

  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    const batch = db.batch();
    for (const r of recipients) {
      batch.create(db.collection('pushLog').doc(), {
        uid: r.uid,
        kind,
        ...render(kind, r.language, params),
        data,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return;
  }

  for (const language of ['en', 'ta'] as const) {
    const uids = recipients.filter((r) => r.language === language).map((r) => r.uid);
    const tokens: { token: string; ref: FirebaseFirestore.DocumentReference }[] = [];
    for (const uid of uids) {
      const devices = await db.collection(`users/${uid}/devices`).get();
      for (const doc of devices.docs) tokens.push({ token: doc.id, ref: doc.ref });
    }
    // FCM takes at most 500 tokens per call.
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const response = await options.messaging().sendEachForMulticast({
        tokens: chunk.map((t) => t.token),
        notification: render(kind, language, params),
        data,
        android: { priority: 'high', notification: { channelId: 'alerts' } },
      });
      response.responses.forEach((res, j) => {
        if (!res.success && res.error && STALE_TOKEN_ERRORS.has(res.error.code)) {
          // The app was uninstalled or the token rotated; stop trying it.
          chunk[j].ref.delete().catch((e) => logger.warn('Could not delete stale token', e));
        }
      });
    }
  }
}
