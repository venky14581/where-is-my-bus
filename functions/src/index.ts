// Alerts for riders. Every trigger fires on a trip, a stop time, a driver
// report or an announcement, never on a position update (see CLAUDE.md).

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, type DocumentSnapshot, type Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import {
  approachingRiders,
  minutesLate,
  prefsOf,
  shouldAlertDelay,
  shouldPush,
  type AlertKind,
  type Direction,
  type Rider,
  type Stop,
} from './audience.js';
import type { Language, MessageParams } from './messages.js';
import { deliver, type Recipient } from './push.js';

initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const db = getFirestore();

interface Student extends Rider {
  language: Language;
}

async function studentsOn(routeId: string): Promise<Student[]> {
  const snap = await db.collection('users').where('role', '==', 'student').where('routeId', '==', routeId).get();
  return snap.docs.map((doc) => studentFrom(doc));
}

async function allStudents(): Promise<Student[]> {
  const snap = await db.collection('users').where('role', '==', 'student').get();
  return snap.docs.map((doc) => studentFrom(doc));
}

function studentFrom(doc: DocumentSnapshot): Student {
  const data = doc.data() ?? {};
  return {
    uid: doc.id,
    stopId: typeof data.stopId === 'string' ? data.stopId : null,
    prefs: prefsOf(data.alerts),
    language: data.language === 'ta' ? 'ta' : 'en',
  };
}

function recipients(students: Student[], kind: AlertKind, now: Date): Recipient[] {
  return students
    .filter((s) => shouldPush(s.prefs, kind, now))
    .map((s) => ({ uid: s.uid, language: s.language }));
}

/** Adds to the in-app alerts list that every rider of the route can read. */
async function postToFeed(routeId: string | null, kind: AlertKind, params: MessageParams, tripId?: string) {
  await db.collection('alerts').add({
    routeId,
    kind,
    params,
    tripId: tripId ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function tripContext(tripId: string) {
  const trip = await db.doc(`trips/${tripId}`).get();
  const data = trip.data();
  if (!data) return null;
  const [route, bus] = await Promise.all([
    db.doc(`routes/${data.routeId}`).get(),
    db.doc(`buses/${data.busId}`).get(),
  ]);
  return {
    trip: data,
    routeId: data.routeId as string,
    routeName: (route.get('name') as string | undefined) ?? '',
    stops: (route.get('stops') as (Stop & { name: string })[] | undefined) ?? [],
    busNumber: (bus.get('number') as string | undefined) ?? (data.busId as string),
    direction: (data.direction === 'fromCampus' ? 'fromCampus' : 'toCampus') as Direction,
  };
}

/** The driver started a trip: riders know the bus is running today. */
export const onTripStarted = onDocumentCreated('trips/{tripId}', async (event) => {
  const tripId = event.params.tripId;
  const ctx = await tripContext(tripId);
  if (!ctx || ctx.trip.status !== 'running') return;
  const params = { busNumber: ctx.busNumber, routeName: ctx.routeName };
  await postToFeed(ctx.routeId, 'tripStarted', params, tripId);
  await deliver({
    db,
    messaging: getMessaging,
    recipients: recipients(await studentsOn(ctx.routeId), 'tripStarted', new Date()),
    kind: 'tripStarted',
    params,
    data: { tripId, routeId: ctx.routeId },
  });
});

/**
 * The bus reached a stop. Tell riders a few stops ahead that it is coming,
 * and the whole route if it has fallen well behind the timetable.
 */
export const onStopReached = onDocumentCreated('trips/{tripId}/stopTimes/{stopId}', async (event) => {
  const { tripId, stopId } = event.params;
  const ctx = await tripContext(tripId);
  if (!ctx) return;
  const now = new Date();
  const students = await studentsOn(ctx.routeId);

  // Approaching: once per student per trip, whichever stop triggers it first.
  const due = approachingRiders({ stops: ctx.stops, direction: ctx.direction, reachedStopId: stopId, riders: students });
  for (const { uid, stopsAway } of due) {
    const student = students.find((s) => s.uid === uid)!;
    if (!shouldPush(student.prefs, 'approaching', now)) continue;
    try {
      await db.doc(`trips/${tripId}/approachingSent/${uid}`).create({ at: FieldValue.serverTimestamp() });
    } catch {
      continue; // already told on this trip
    }
    const stopName = ctx.stops.find((s) => s.id === student.stopId)?.name;
    await deliver({
      db,
      messaging: getMessaging,
      recipients: [{ uid, language: student.language }],
      kind: 'approaching',
      params: { busNumber: ctx.busNumber, stopName, stopsAway },
      data: { tripId, routeId: ctx.routeId },
    });
  }

  // Delay: morning only, since the timetable holds morning times.
  if (ctx.direction !== 'toCampus') return;
  const arrivedAt = (event.data?.get('arrivedAt') as Timestamp | undefined)?.toDate();
  const scheduledTime = ctx.stops.find((s) => s.id === stopId)?.scheduledTime;
  if (!arrivedAt || !scheduledTime) return;
  const late = minutesLate({ tripDate: ctx.trip.date as string, scheduledTime, arrivedAt });
  if (late === null) return;

  const tripRef = db.doc(`trips/${tripId}`);
  const alert = await db.runTransaction(async (tx) => {
    const already = ((await tx.get(tripRef)).get('delayAlertedMinutes') as number | undefined) ?? 0;
    if (!shouldAlertDelay(late, already)) return false;
    tx.update(tripRef, { delayAlertedMinutes: late });
    return true;
  });
  if (!alert) return;
  const params = { busNumber: ctx.busNumber, routeName: ctx.routeName, minutes: late };
  await postToFeed(ctx.routeId, 'delay', params, tripId);
  await deliver({
    db,
    messaging: getMessaging,
    recipients: recipients(students, 'delay', now),
    kind: 'delay',
    params,
    data: { tripId, routeId: ctx.routeId },
  });
});

/** The driver tapped Running late or Breakdown. */
export const onDriverReport = onDocumentCreated('trips/{tripId}/reports/{reportId}', async (event) => {
  const tripId = event.params.tripId;
  const type = event.data?.get('type');
  if (type !== 'late' && type !== 'breakdown') return;
  const ctx = await tripContext(tripId);
  if (!ctx) return;
  const params = { busNumber: ctx.busNumber, routeName: ctx.routeName };
  await postToFeed(ctx.routeId, type, params, tripId);
  await deliver({
    db,
    messaging: getMessaging,
    recipients: recipients(await studentsOn(ctx.routeId), type, new Date()),
    kind: type,
    params,
    data: { tripId, routeId: ctx.routeId },
  });
});

/** The transport office posted an announcement, to one route or to all. */
export const onAnnouncement = onDocumentCreated('announcements/{id}', async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const routeId = typeof data.routeId === 'string' ? data.routeId : null;
  const students = routeId ? await studentsOn(routeId) : await allStudents();
  logger.info(`Announcement ${event.params.id} to ${students.length} students`);
  await deliver({
    db,
    messaging: getMessaging,
    recipients: recipients(students, 'announcement', new Date()),
    kind: 'announcement',
    params: { title: String(data.title ?? ''), body: String(data.body ?? '') },
    data: { announcementId: event.params.id, ...(routeId ? { routeId } : {}) },
  });
});
