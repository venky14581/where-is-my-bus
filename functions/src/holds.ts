// Missed-bus help: a student who missed their bus holds a seat on another
// college bus the office authorized for their route. Seat counts change only
// in transactions, so a seat cannot be given twice (CLAUDE.md).

import { FieldValue, type Transaction } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './app.js';
import { passIsCurrent } from './boarding.js';
import { spareSeats } from './booking.js';
import {
  campusDate,
  countsAsSeat,
  hasPassed,
  holdsLeftBehind,
  mayRideAlternate,
  pickupStopIds,
  type Direction,
} from './missedBus.js';

export type HoldResult = 'held' | 'full' | 'passed' | 'notAllowed' | 'noPass' | 'notRunning' | 'badStop';

const directionOf = (value: unknown): Direction => (value === 'fromCampus' ? 'fromCampus' : 'toCampus');

/** Students on [routeId] whose pass is valid now. Each keeps a seat. */
export async function countPassHolders(routeId: string, now: Date): Promise<number> {
  const snap = await db.collection('users').where('role', '==', 'student').where('routeId', '==', routeId).get();
  return snap.docs.filter((d) =>
    passIsCurrent({
      passValid: d.get('passValid') === true,
      passValidUntil: typeof d.get('passValidUntil') === 'string' ? d.get('passValidUntil') : null,
    }, now),
  ).length;
}

/**
 * A trip started: note how many seats its own pass holders keep, so other
 * routes' riders can see what is left. Safe to run twice.
 */
export const countTripSeats = onDocumentCreated('trips/{tripId}', async (event) => {
  const routeId = event.data?.get('routeId');
  if (typeof routeId !== 'string') return;
  const passHolders = await countPassHolders(routeId, new Date());
  const ref = db.doc(`trips/${event.params.tripId}`);
  await db.runTransaction(async (tx) => {
    const trip = await tx.get(ref);
    if (!trip.exists || typeof trip.get('passHolders') === 'number') return;
    tx.update(ref, { passHolders, altHeld: trip.get('altHeld') ?? 0 });
  });
});

/** Releases the seat of a hold still `held`, as [status]. Reads then writes. */
async function releaseIn(tx: Transaction, tripId: string, uid: string, status: 'cancelled' | 'missed'): Promise<boolean> {
  const holdRef = db.doc(`trips/${tripId}/holds/${uid}`);
  const hold = await tx.get(holdRef);
  if (!hold.exists || hold.get('status') !== 'held') return false;
  tx.update(holdRef, { status, endedAt: FieldValue.serverTimestamp() });
  tx.update(db.doc(`trips/${tripId}`), { altHeld: FieldValue.increment(-1) });
  return true;
}

/**
 * Hold a seat on [tripId] at [stopId]. One hold per student: holding on
 * another bus gives up the earlier seat.
 */
export const holdSeat = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { tripId, stopId } = request.data ?? {};
  if (typeof tripId !== 'string' || typeof stopId !== 'string') throw new HttpsError('invalid-argument', 'Which bus and stop?');
  const now = new Date();
  const answer = (result: HoldResult) => ({ result });

  const student = await db.doc(`users/${uid}`).get();
  if (student.get('role') !== 'student') throw new HttpsError('permission-denied', 'Only students can hold a seat.');
  const studentRoute = typeof student.get('routeId') === 'string' ? (student.get('routeId') as string) : null;
  if (!passIsCurrent({
    passValid: student.get('passValid') === true,
    passValidUntil: typeof student.get('passValidUntil') === 'string' ? student.get('passValidUntil') : null,
  }, now)) return answer('noPass');

  const tripRef = db.doc(`trips/${tripId}`);
  const first = await tripRef.get();
  if (!first.exists || first.get('status') !== 'running' || first.get('date') !== campusDate(now)) return answer('notRunning');
  const tripRoute = first.get('routeId') as string;
  const direction = directionOf(first.get('direction'));
  const [route, access, bus, recorded, others] = await Promise.all([
    db.doc(`routes/${tripRoute}`).get(),
    db.doc(`routeAccess/${tripRoute}`).get(),
    db.doc(`buses/${first.get('busId')}`).get(),
    tripRef.collection('stopTimes').get(),
    // Other buses running today, to give up a seat held on one of them.
    db.collection('trips').where('date', '==', campusDate(now)).where('status', '==', 'running').get(),
  ]);
  if (!mayRideAlternate(tripRoute, studentRoute, access.get('acceptsFrom'))) return answer('notAllowed');
  const stopIds = (route.get('stopIds') as string[] | undefined) ?? [];
  if (!pickupStopIds(stopIds, direction).includes(stopId)) return answer('badStop');
  if (hasPassed(stopIds, direction, stopId, recorded.docs.map((d) => d.id))) return answer('passed');
  const capacity = typeof bus.get('capacity') === 'number' ? (bus.get('capacity') as number) : 0;
  // Normally set when the trip started; counted here if that has not run yet.
  const passHolders = typeof first.get('passHolders') === 'number'
    ? (first.get('passHolders') as number)
    : await countPassHolders(tripRoute, now);
  const name = String(student.get('name') ?? '');

  const result = await db.runTransaction(async (tx): Promise<HoldResult> => {
    const holdRef = tripRef.collection('holds').doc(uid);
    const [trip, mine] = await Promise.all([tx.get(tripRef), tx.get(holdRef)]);
    if (trip.get('status') !== 'running') return 'notRunning';
    const elsewhere = others.docs.filter((d) => d.id !== tripId);
    const otherHolds = await Promise.all(elsewhere.map((d) => tx.get(d.ref.collection('holds').doc(uid))));

    // Already holding here: just move the pickup stop.
    if (mine.exists && countsAsSeat(mine.get('status'))) {
      if (mine.get('status') === 'held') tx.update(holdRef, { stopId });
      return 'held';
    }
    const held = typeof trip.get('altHeld') === 'number' ? (trip.get('altHeld') as number) : 0;
    const booked = typeof trip.get('seatsBooked') === 'number' ? (trip.get('seatsBooked') as number) : 0;
    const notRiding = typeof trip.get('notRiding') === 'number' ? (trip.get('notRiding') as number) : 0;
    if (spareSeats({ capacity, passHolders, notRiding, altHeld: held, seatsBooked: booked }) <= 0) return 'full';

    for (const other of otherHolds) {
      if (other.exists && other.get('status') === 'held') {
        tx.update(other.ref, { status: 'cancelled', endedAt: FieldValue.serverTimestamp() });
        tx.update(other.ref.parent.parent!, { altHeld: FieldValue.increment(-1) });
      }
    }
    tx.set(holdRef, {
      uid,
      name,
      fromRouteId: studentRoute,
      stopId,
      status: 'held',
      at: FieldValue.serverTimestamp(),
    });
    tx.update(tripRef, {
      altHeld: FieldValue.increment(1),
      ...(typeof trip.get('passHolders') === 'number' ? {} : { passHolders }),
    });
    return 'held';
  });
  return answer(result);
});

/** The student no longer needs the seat. */
export const cancelHold = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const tripId = request.data?.tripId;
  if (typeof tripId !== 'string') throw new HttpsError('invalid-argument', 'Which bus?');
  const released = await db.runTransaction((tx) => releaseIn(tx, tripId, uid, 'cancelled'));
  return { result: released ? 'cancelled' : 'none' };
});

/**
 * The bus reached a stop: seats held at stops it has now left behind go
 * back to the pool. A rider at the stop it just reached may still board.
 */
export const releasePassedHolds = onDocumentCreated('trips/{tripId}/stopTimes/{stopId}', async (event) => {
  const { tripId, stopId } = event.params;
  const trip = await db.doc(`trips/${tripId}`).get();
  if (!trip.exists) return;
  const [route, holds] = await Promise.all([
    db.doc(`routes/${trip.get('routeId')}`).get(),
    db.collection(`trips/${tripId}/holds`).where('status', '==', 'held').get(),
  ]);
  const behind = holdsLeftBehind({
    stopIds: (route.get('stopIds') as string[] | undefined) ?? [],
    direction: directionOf(trip.get('direction')),
    reachedStopId: stopId,
    holds: holds.docs.map((d) => ({ uid: d.id, stopId: String(d.get('stopId')) })),
  });
  for (const uid of behind) {
    await db.runTransaction((tx) => releaseIn(tx, tripId, uid, 'missed'));
  }
});
