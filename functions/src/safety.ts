// Safety (Module 12): SOS, the parent's trip link, and office alerts for
// overspeeding and leaving the route. Speed and route are checked on the
// driver's phone, which writes one event per episode, so nothing here runs
// on every position update (CLAUDE.md).

import { randomBytes } from 'node:crypto';

import { getDatabaseWithUrl } from 'firebase-admin/database';
import { FieldValue, Timestamp, type DocumentSnapshot } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { app, db } from './app.js';
import { databaseUrl } from './mirror.js';
import { campusDate } from './missedBus.js';

export type SafetyType = 'sos' | 'overspeed' | 'offRoute';

/** A parent's link works this long at most, even if the trip is never ended. */
export const SHARE_HOURS = 12;

export function newShareToken(): string {
  return randomBytes(16).toString('base64url');
}

/** Whether a shared trip can still be followed. */
export function shareState(
  share: { expiresAt: Date } | null,
  trip: { status?: unknown } | null,
  now: Date,
): 'ok' | 'ended' | 'notFound' {
  if (!share || !trip) return 'notFound';
  if (now >= share.expiresAt || trip.status === 'ended') return 'ended';
  return 'ok';
}

/** Only what an event may say; anything else from the phone is dropped. */
export function eventDetails(data: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const key of ['speedKmh', 'limitKmh', 'distanceM'] as const) {
    if (typeof data[key] === 'number' && Number.isFinite(data[key])) out[key] = Math.round(data[key] as number);
  }
  return out;
}

async function busPosition(busId: string): Promise<{ lat: number; lng: number; updatedAt: number | null } | null> {
  const live = (await getDatabaseWithUrl(databaseUrl(), app).ref(`live/${busId}`).get()).val() as
    | { lat?: number; lng?: number; updatedAt?: number }
    | null;
  return typeof live?.lat === 'number' && typeof live.lng === 'number'
    ? { lat: live.lat, lng: live.lng, updatedAt: typeof live.updatedAt === 'number' ? live.updatedAt : null }
    : null;
}

/** Names the office needs to act on an alert about [trip]. */
async function tripLabels(trip: DocumentSnapshot) {
  const [bus, route, driver] = await Promise.all([
    db.doc(`buses/${trip.get('busId')}`).get(),
    db.doc(`routes/${trip.get('routeId')}`).get(),
    typeof trip.get('driverId') === 'string' ? db.doc(`users/${trip.get('driverId')}`).get() : null,
  ]);
  return {
    tripId: trip.id,
    busId: String(trip.get('busId') ?? ''),
    busNumber: String(bus.get('number') ?? trip.get('busId') ?? ''),
    routeId: String(trip.get('routeId') ?? ''),
    routeName: String(route.get('name') ?? ''),
    driverName: driver ? String(driver.get('name') ?? '') : '',
  };
}

/**
 * The trip [uid] is on now: a driver's own running trip, or for a student
 * the running trip of their route today. Null when there is none.
 */
async function currentTripOf(uid: string, now: Date): Promise<{ trip: DocumentSnapshot; role: string; name: string; user: DocumentSnapshot } | null> {
  const user = await db.doc(`users/${uid}`).get();
  const role = user.get('role');
  const running = db.collection('trips').where('date', '==', campusDate(now)).where('status', '==', 'running');
  let found: DocumentSnapshot | undefined;
  if (role === 'driver') {
    found = (await running.where('driverId', '==', uid).get()).docs[0];
  } else if (role === 'student' && typeof user.get('routeId') === 'string') {
    const trips = (await running.where('routeId', '==', user.get('routeId')).get()).docs;
    // Morning and evening may both be marked running; the latest started is the one on the road.
    found = trips.sort((a, b) => (b.get('startedAt')?.toMillis?.() ?? 0) - (a.get('startedAt')?.toMillis?.() ?? 0))[0];
  } else {
    throw new HttpsError('permission-denied', 'Students and drivers only.');
  }
  return found ? { trip: found, role, name: String(user.get('name') ?? ''), user } : null;
}

/**
 * SOS: the bus number and where the bus is, to the transport office. From
 * the driver or a student on that route; the student's own location is
 * never sent. Pressing again refreshes the same alert.
 */
export const sendSos = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const now = new Date();
  const current = await currentTripOf(uid, now);
  if (!current) return { result: 'noTrip' };
  const { trip, role, name } = current;
  const labels = await tripLabels(trip);
  const position = await busPosition(labels.busId);
  await db.doc(`safetyAlerts/sos_${trip.id}_${uid}`).set({
    type: 'sos' satisfies SafetyType,
    ...labels,
    fromUid: uid,
    fromRole: role,
    fromName: name,
    lat: position?.lat ?? null,
    lng: position?.lng ?? null,
    details: {},
    status: 'open',
    at: FieldValue.serverTimestamp(),
    acknowledgedBy: null,
    acknowledgedAt: null,
  });
  return { result: 'sent' };
});

/**
 * The driver's phone saw the bus overspeeding or off its route: tell the
 * office. Once per event, however often the trigger runs.
 */
export const onSafetyEvent = onDocumentCreated('trips/{tripId}/events/{eventId}', async (event) => {
  const data = event.data?.data();
  const type = data?.type;
  if (type !== 'overspeed' && type !== 'offRoute') return;
  const trip = await db.doc(`trips/${event.params.tripId}`).get();
  if (!trip.exists) return;
  try {
    await db.doc(`safetyAlerts/${event.params.tripId}_${event.params.eventId}`).create({
      type,
      ...(await tripLabels(trip)),
      fromUid: trip.get('driverId') ?? null,
      fromRole: 'driver',
      fromName: '',
      lat: typeof data!.lat === 'number' ? data!.lat : null,
      lng: typeof data!.lng === 'number' ? data!.lng : null,
      details: eventDetails(data!),
      status: 'open',
      at: data!.createdAt ?? FieldValue.serverTimestamp(),
      acknowledgedBy: null,
      acknowledgedAt: null,
    });
  } catch (e) {
    if ((e as { code?: number }).code !== 6) throw e; // already alerted
  }
});

/** A student shares their running trip with a parent. */
export const shareTrip = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (request.auth?.token.email_verified !== true) throw new HttpsError('permission-denied', 'Verify your email first.');
  const now = new Date();
  const current = await currentTripOf(uid, now);
  if (current?.role !== 'student') {
    if (current) throw new HttpsError('permission-denied', 'Students only.');
    return { result: 'noTrip' };
  }
  const token = newShareToken();
  await db.doc(`shares/${token}`).create({
    tripId: current.trip.id,
    uid,
    stopId: current.user.get('stopId') ?? null,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(now.getTime() + SHARE_HOURS * 3600_000),
  });
  return { result: 'shared', token };
});

/**
 * What a parent's link shows: the one bus, its route and the student's
 * stop. No sign-in; the unguessable token is the permission, and it stops
 * working when the trip ends.
 */
export const viewSharedTrip = onCall(async (request) => {
  const token = request.data?.token;
  if (typeof token !== 'string' || !/^[\w-]{16,64}$/.test(token)) return { result: 'notFound' };
  const share = await db.doc(`shares/${token}`).get();
  const trip = share.exists ? await db.doc(`trips/${share.get('tripId')}`).get() : null;
  const now = new Date();
  const state = shareState(
    share.exists ? { expiresAt: (share.get('expiresAt') as Timestamp).toDate() } : null,
    trip?.exists ? trip.data()! : null,
    now,
  );
  if (state !== 'ok') return { result: state };
  const labels = await tripLabels(trip!);
  const route = await db.doc(`routes/${labels.routeId}`).get();
  const stops = ((route.get('stops') as { id: string; name: string; lat: number; lng: number }[] | undefined) ?? [])
    .map(({ id, name, lat, lng }) => ({ id, name, lat, lng }));
  return {
    result: 'ok',
    busNumber: labels.busNumber,
    routeName: labels.routeName,
    direction: trip!.get('direction'),
    path: route.get('path') ?? null,
    stops,
    stopId: share.get('stopId'),
    bus: await busPosition(labels.busId),
    liveStatus: (await getDatabaseWithUrl(databaseUrl(), app).ref(`live/${labels.busId}/status`).get()).val() ?? null,
    serverNow: now.getTime(),
  };
});
