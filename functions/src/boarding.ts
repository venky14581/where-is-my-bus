// Boarding with a digital bus pass: the driver scans the student's QR and the
// server decides. Pass validity is never checked only in the app (CLAUDE.md).

import { randomBytes } from 'node:crypto';

import { getDatabaseWithUrl } from 'firebase-admin/database';
import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { app, db } from './app.js';
import { databaseUrl } from './mirror.js';
import { checkPass, parsePassCode } from './passCode.js';

export interface PassHolder {
  passValid: boolean;
  /** Last day of validity, YYYY-MM-DD, on the campus clock. */
  passValidUntil: string | null;
}

/** Valid through the whole of the last day, India time (no daylight saving). */
export function passIsCurrent(holder: PassHolder, now: Date): boolean {
  if (!holder.passValid || !holder.passValidUntil || !/^\d{4}-\d{2}-\d{2}$/.test(holder.passValidUntil)) return false;
  const endOfLastDay = new Date(`${holder.passValidUntil}T23:59:59.999+05:30`);
  return now.getTime() <= endOfLastDay.getTime();
}

/**
 * A student given a pass gets a secret for their rotating QR code. Created
 * once and kept, so the pass works offline on their phone.
 */
export const issuePassSecret = onDocumentWritten('users/{uid}', async (event) => {
  const after = event.data?.after;
  if (!after?.exists || after.get('role') !== 'student' || after.get('passValid') !== true) return;
  try {
    await db.doc(`passSecrets/${event.params.uid}`).create({
      secret: randomBytes(32).toString('base64'),
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    if ((e as { code?: number }).code !== 6) throw e; // 6: already has one
  }
});

export type ScanResult =
  | 'boarded'
  | 'alreadyBoarded'
  | 'notAPass'
  | 'invalidCode'
  | 'expiredCode'
  | 'noPass'
  | 'passExpired'
  | 'wrongRoute'
  | 'noSeatHeld';

const metres = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const rad = Math.PI / 180;
  const h = Math.sin(((b.lat - a.lat) * rad) / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(((b.lng - a.lng) * rad) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
};

/**
 * The driver scanned a QR. Only the driver of a running trip can call this.
 * Records the boarding once per student per trip.
 */
export const scanPass = onCall(async (request) => {
  const driverUid = request.auth?.uid;
  if (!driverUid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const tripId = request.data?.tripId;
  if (typeof tripId !== 'string') throw new HttpsError('invalid-argument', 'Which trip?');
  const trip = await db.doc(`trips/${tripId}`).get();
  if (!trip.exists || trip.get('driverId') !== driverUid || trip.get('status') !== 'running') {
    throw new HttpsError('permission-denied', 'Only the driver of a running trip can scan passes.');
  }

  const result = async (outcome: ScanResult, extra: Record<string, unknown> = {}) => ({ result: outcome, ...extra });

  const pass = parsePassCode(request.data?.code);
  if (!pass) return result('notAPass');
  const [secret, student] = await Promise.all([
    db.doc(`passSecrets/${pass.uid}`).get(),
    db.doc(`users/${pass.uid}`).get(),
  ]);
  if (!secret.exists || !student.exists || student.get('role') !== 'student') return result('invalidCode');
  const check = checkPass(pass, secret.get('secret'), Date.now());
  if (check === 'badSignature') return result('invalidCode');
  if (check === 'stale') return result('expiredCode');

  const name = String(student.get('name') ?? '');
  const holder: PassHolder = {
    passValid: student.get('passValid') === true,
    passValidUntil: typeof student.get('passValidUntil') === 'string' ? student.get('passValidUntil') : null,
  };
  if (!holder.passValid) return result('noPass', { name });
  if (!passIsCurrent(holder, new Date())) return result('passExpired', { name });

  // Their own route, or one the office lets them ride (routeAccess).
  const tripRoute = trip.get('routeId') as string;
  const studentRoute = student.get('routeId') as string | null;
  if (studentRoute !== tripRoute) {
    const access = await db.doc(`routeAccess/${tripRoute}`).get();
    const accepts = (access.get('acceptsFrom') as string[] | undefined) ?? [];
    if (!studentRoute || !accepts.includes(studentRoute)) return result('wrongRoute', { name });
  }

  // Where the bus is: the route stop nearest its last position.
  const [route, live] = await Promise.all([
    db.doc(`routes/${tripRoute}`).get(),
    getDatabaseWithUrl(databaseUrl(), app).ref(`live/${trip.get('busId')}`).get(),
  ]);
  const stops = (route.get('stops') as { id: string; lat: number; lng: number }[] | undefined) ?? [];
  const position = live.val() as { lat?: number; lng?: number } | null;
  let stopId: string | null = null;
  if (position?.lat !== undefined && position.lng !== undefined && stops.length > 0) {
    const here = { lat: position.lat, lng: position.lng };
    stopId = stops.reduce((best, s) => (metres(here, s) < metres(here, best) ? s : best)).id;
  }

  // A rider from another route boards only with a seat held in the app
  // (missed-bus help), so the seat count stays true. Boarding uses it up.
  const alternate = studentRoute !== tripRoute;
  const boardingRef = db.doc(`trips/${tripId}/boardings/${pass.uid}`);
  const holdRef = db.doc(`trips/${tripId}/holds/${pass.uid}`);
  const outcome = await db.runTransaction(async (tx): Promise<ScanResult> => {
    const [boarding, hold] = await Promise.all([tx.get(boardingRef), tx.get(holdRef)]);
    if (boarding.exists) return 'alreadyBoarded';
    if (alternate && hold.get('status') !== 'held') return 'noSeatHeld';
    tx.create(boardingRef, {
      type: alternate ? 'alternate' : 'pass',
      name,
      stopId,
      at: FieldValue.serverTimestamp(),
    });
    if (alternate) tx.update(holdRef, { status: 'boarded', endedAt: FieldValue.serverTimestamp() });
    return 'boarded';
  });
  return result(outcome, { name });
});
