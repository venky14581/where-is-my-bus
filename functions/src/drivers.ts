// Office-only driver accounts. Creating a login for someone else and changing
// their PIN need admin rights, so the dashboard calls these instead of
// touching Firebase Auth itself.

import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';

import { app, db } from './app.js';

/** Keep in step with AppConfig.driverEmailDomain in the app. */
export const DRIVER_EMAIL_DOMAIN = 'drivers.whereismybus.invalid';

export function normalizeDriverId(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const id = raw.trim().toUpperCase();
  return /^[A-Z0-9-]{3,16}$/.test(id) ? id : null;
}

/** 6 digits: Firebase's minimum password length. */
export function validPin(raw: unknown): raw is string {
  return typeof raw === 'string' && /^\d{6}$/.test(raw);
}

export function validName(raw: unknown): raw is string {
  return typeof raw === 'string' && raw.trim().length > 0 && raw.trim().length <= 80;
}

export const driverEmailFor = (driverId: string) => `${driverId.toLowerCase()}@${DRIVER_EMAIL_DOMAIN}`;

async function requireOffice(request: CallableRequest): Promise<void> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const profile = await db.doc(`users/${uid}`).get();
  if (profile.get('role') !== 'office') throw new HttpsError('permission-denied', 'Transport office only.');
}

/** Creates the sign-in for a driver ID and its driver profile. */
export const createDriver = onCall(async (request) => {
  await requireOffice(request);
  const driverId = normalizeDriverId(request.data?.driverId);
  if (!driverId) throw new HttpsError('invalid-argument', 'Driver ID: 3 to 16 letters, numbers or dashes.');
  if (!validName(request.data?.name)) throw new HttpsError('invalid-argument', 'Name is required.');
  if (!validPin(request.data?.pin)) throw new HttpsError('invalid-argument', 'PIN must be 6 digits.');

  const taken = await db.collection('users').where('driverId', '==', driverId).limit(1).get();
  if (!taken.empty) throw new HttpsError('already-exists', `Driver ${driverId} already exists.`);

  const name = (request.data.name as string).trim();
  let user;
  try {
    user = await getAuth(app).createUser({
      email: driverEmailFor(driverId),
      password: request.data.pin,
      displayName: name,
    });
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', `Driver ${driverId} already has a sign-in.`);
    }
    throw e;
  }
  await db.doc(`users/${user.uid}`).set({
    name,
    role: 'driver',
    driverId,
    // Null so the driver picks a language at first sign-in.
    language: null,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { uid: user.uid, driverId };
});

/** Sets a new PIN, e.g. when a driver forgets theirs. */
export const setDriverPin = onCall(async (request) => {
  await requireOffice(request);
  const uid = request.data?.uid;
  if (typeof uid !== 'string' || uid.length === 0) throw new HttpsError('invalid-argument', 'Which driver?');
  if (!validPin(request.data?.pin)) throw new HttpsError('invalid-argument', 'PIN must be 6 digits.');
  const profile = await db.doc(`users/${uid}`).get();
  if (profile.get('role') !== 'driver') throw new HttpsError('not-found', 'No such driver.');
  await getAuth(app).updateUser(uid, { password: request.data.pin });
  return { ok: true };
});
