// Smart features (Module 11) on the server: how slow today's buses are
// running, the leave-home reminder, and Not riding today.

import { FieldValue, type Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from './app.js';
import { shouldPush, type AlertPrefs } from './audience.js';
import { passIsCurrent } from './boarding.js';
import { spareSeats } from './booking.js';
import { leaveAt, learnedSegments, secondsBetween, trafficFactor, type Conditions, type LearnedTimes } from './learned.js';
import type { Language } from './messages.js';
import { campusDate } from './missedBus.js';
import { deliver } from './push.js';
import { claim } from './runs.js';

type Direction = 'toCampus' | 'fromCampus';
interface RouteStop {
  id: string;
  name?: string;
  scheduledTime?: string;
}

const minutesOf = (hhmm: unknown): number | null => {
  if (typeof hhmm !== 'string' || !/^\d{1,2}:\d{2}$/.test(hhmm)) return null;
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

const learnedFor = async (routeId: string) => (await db.doc(`segmentTimes/${routeId}`).get()).data() as LearnedTimes | undefined;
const conditionsOn = async (date: string) => (await db.doc(`conditions/${date}`).get()).data() as Conditions | undefined;

/** HH:MM on the campus clock. */
const clockText = (at: Date) => new Date(at.getTime() + 5.5 * 3600_000).toISOString().slice(11, 16);

/**
 * A stretch between two stops was driven: note how its time compared with
 * what was expected, so later estimates today can allow for rain or
 * traffic. Once per stop time.
 */
export const noteTraffic = onDocumentCreated('trips/{tripId}/stopTimes/{stopId}', async (event) => {
  const { tripId, stopId } = event.params;
  const arrivedAt = (event.data?.get('arrivedAt') as Timestamp | undefined)?.toDate();
  if (!arrivedAt) return;
  const trip = await db.doc(`trips/${tripId}`).get();
  const routeId = trip.get('routeId');
  if (typeof routeId !== 'string') return;
  const direction: Direction = trip.get('direction') === 'fromCampus' ? 'fromCampus' : 'toCampus';
  const stops = ((await db.doc(`routes/${routeId}`).get()).get('stops') as RouteStop[] | undefined) ?? [];
  const here = stops.findIndex((s) => s.id === stopId);
  const before = direction === 'toCampus' ? here - 1 : here + 1;
  if (here < 0 || before < 0 || before >= stops.length) return;
  const previous = await trip.ref.collection('stopTimes').doc(stops[before].id).get();
  const leftAt = (previous.get('arrivedAt') as Timestamp | undefined)?.toDate();
  if (!leftAt) return;
  const actual = (arrivedAt.getTime() - leftAt.getTime()) / 1000;
  const expected = secondsBetween(before, here, {
    segments: learnedSegments(await learnedFor(routeId), direction, leftAt, stops.length),
    timetableMinutes: stops.map((s) => minutesOf(s.scheduledTime)),
  });
  if (actual <= 0 || !expected) return;
  if (!(await claim(`traffic_${tripId}_${stopId}`))) return;
  // One odd stretch (a long wait at a stop) should not swing the day.
  const ratio = Math.min(3, Math.max(0.5, actual / expected));
  await db.doc(`conditions/${campusDate(arrivedAt)}`).set(
    { ratioSum: FieldValue.increment(ratio), count: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
});

export interface Walker {
  uid: string;
  stopId: string | null;
  prefs: AlertPrefs;
  language: Language;
  walkMinutes: number | null;
}

/**
 * The bus has just reached the stop at [reachedIndex] (or started there).
 * Tells each rider ahead who gave their walk to the stop when it is time to
 * leave: at this stop if leaving before the next one is reached, so the
 * reminder is never late by more than one stretch. Once per rider per trip.
 */
export async function remindToLeave(options: {
  tripId: string;
  routeId: string;
  busNumber: string;
  stops: RouteStop[];
  direction: Direction;
  reachedIndex: number;
  riders: Walker[];
  now: Date;
}): Promise<void> {
  const { tripId, routeId, stops, reachedIndex, now } = options;
  // Evening riders board at campus; there is no home to leave.
  if (options.direction !== 'toCampus' || reachedIndex < 0) return;
  const walkers = options.riders.filter((r) => r.walkMinutes !== null && r.walkMinutes > 0 && shouldPush(r.prefs, 'leaveHome', now));
  if (walkers.length === 0) return;
  const estimate = {
    segments: learnedSegments(await learnedFor(routeId), 'toCampus', now, stops.length),
    timetableMinutes: stops.map((s) => minutesOf(s.scheduledTime)),
    factor: trafficFactor(await conditionsOn(campusDate(now))),
  };
  const untilNextStop = reachedIndex + 1 < stops.length ? secondsBetween(reachedIndex, reachedIndex + 1, estimate) ?? 0 : 0;
  for (const rider of walkers) {
    const theirs = stops.findIndex((s) => s.id === rider.stopId);
    if (theirs <= reachedIndex) continue;
    const eta = secondsBetween(reachedIndex, theirs, estimate);
    if (eta === null) continue;
    const busThere = new Date(now.getTime() + eta * 1000);
    // Not yet: a later stop will still be in time (a minute's margin).
    if (leaveAt(busThere, rider.walkMinutes!).getTime() > now.getTime() + (untilNextStop + 60) * 1000) continue;
    try {
      await db.doc(`trips/${tripId}/leaveSent/${rider.uid}`).create({ at: FieldValue.serverTimestamp() });
    } catch {
      continue; // already told on this trip
    }
    await deliver({
      db,
      messaging: getMessaging,
      recipients: [{ uid: rider.uid, language: rider.language }],
      kind: 'leaveHome',
      params: { busNumber: options.busNumber, stopName: stops[theirs].name, time: clockText(busThere) },
      data: { tripId, routeId },
    });
  }
}

export type NotRidingResult = 'notRiding' | 'riding' | 'locked' | 'seatTaken' | 'notYourBus' | 'noPass';

/**
 * A pass holder will not take their route's evening bus: their seat can be
 * booked by a guest. Changeable until booking closes; taking it back fails
 * once the seat has been sold.
 */
export const setNotRiding = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { tripId, notRiding } = request.data ?? {};
  if (typeof tripId !== 'string' || typeof notRiding !== 'boolean') throw new HttpsError('invalid-argument', 'Which bus, riding or not?');
  const now = new Date();
  const answer = (result: NotRidingResult) => ({ result });

  const [student, first] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`trips/${tripId}`).get()]);
  if (student.get('role') !== 'student') throw new HttpsError('permission-denied', 'Only students.');
  if (!first.exists || first.get('direction') !== 'fromCampus' || !first.get('bookingClosesAt')) {
    throw new HttpsError('not-found', 'No evening bus to give up.');
  }
  if (student.get('routeId') !== first.get('routeId')) return answer('notYourBus');
  if (!passIsCurrent({
    passValid: student.get('passValid') === true,
    passValidUntil: typeof student.get('passValidUntil') === 'string' ? student.get('passValidUntil') : null,
  }, now)) return answer('noPass');

  const tripRef = first.ref;
  const markRef = tripRef.collection('notRiding').doc(uid);
  const result = await db.runTransaction(async (tx): Promise<NotRidingResult> => {
    const [trip, mark] = await Promise.all([tx.get(tripRef), tx.get(markRef)]);
    const closes = (trip.get('bookingClosesAt') as Timestamp).toDate();
    if (now >= closes || trip.get('status') !== 'scheduled') return 'locked';
    if (notRiding) {
      if (mark.exists) return 'notRiding';
      tx.create(markRef, { at: FieldValue.serverTimestamp() });
      tx.update(tripRef, { notRiding: FieldValue.increment(1) });
      return 'notRiding';
    }
    if (!mark.exists) return 'riding';
    const free = spareSeats({
      capacity: trip.get('capacity') ?? 0,
      passHolders: trip.get('passHolders') ?? 0,
      notRiding: trip.get('notRiding') ?? 0,
      altHeld: trip.get('altHeld') ?? 0,
      seatsBooked: trip.get('seatsBooked') ?? 0,
    });
    // Their seat went to a guest and none is left to give back.
    if (free <= 0) return 'seatTaken';
    tx.delete(markRef);
    tx.update(tripRef, { notRiding: FieldValue.increment(-1) });
    return 'riding';
  });
  return answer(result);
});
