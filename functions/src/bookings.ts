// Evening seat booking (Module 10). Students without a pass for a route book
// a spare seat on its evening bus and pay per ride. Booking times, seat
// counts and payment are checked here, never only in the app, and seat
// counts change only in transactions (CLAUDE.md).

import { FieldValue, Timestamp, type DocumentSnapshot, type Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db } from './app.js';
import { passIsCurrent } from './boarding.js';
import {
  PAYMENT_MINUTES,
  bookingIdFor,
  bookingSettingsOf,
  bookingWindow,
  dayAfter,
  eveningSchedule,
  holdsSeat,
  newTicketToken,
  razorpaySignatureValid,
  spareSeats,
} from './booking.js';
import { countPassHolders } from './holds.js';
import { campusDate } from './missedBus.js';

const TIME_ZONE = 'Asia/Kolkata';

/**
 * Demo payments stand in for a gateway, on the emulators only, so a real
 * project never gives away seats for nothing.
 */
const demoPayments = () => process.env.FUNCTIONS_EMULATOR === 'true';

/** Razorpay test or live keys, from the functions' environment (never committed). */
function razorpayKeys(): { keyId: string; keySecret: string } | null {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  return keyId && keySecret ? { keyId, keySecret } : null;
}

/** Creates a Razorpay order for [amountRupees]; Razorpay counts in paise. */
async function razorpayOrder(keys: { keyId: string; keySecret: string }, amountRupees: number, receipt: string): Promise<string> {
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${keys.keyId}:${keys.keySecret}`).toString('base64')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ amount: Math.round(amountRupees * 100), currency: 'INR', receipt: receipt.slice(-40) }),
  });
  if (!response.ok) throw new Error(`Razorpay order failed: ${response.status}`);
  return ((await response.json()) as { id: string }).id;
}

// ---------------------------------------------------------------------------
// Evening trips

/**
 * Creates the evening trips for [now]'s date (if still to leave) and the
 * next day, one per bus with a route, so booking can open the evening
 * before. Safe to run any number of times.
 */
export async function scheduleEveningTrips(now: Date): Promise<string[]> {
  const settings = bookingSettingsOf((await db.doc('settings/booking').get()).data());
  const [buses, routes] = await Promise.all([db.collection('buses').get(), db.collection('routes').get()]);
  const routeById = new Map(routes.docs.map((r) => [r.id, r]));
  const created: string[] = [];
  const today = campusDate(now);
  for (const date of [today, dayAfter(today)]) {
    const schedule = eveningSchedule(date, settings);
    if (schedule.departsAt <= now) continue;
    for (const bus of buses.docs) {
      const routeId = bus.get('routeId');
      const route = typeof routeId === 'string' ? routeById.get(routeId) : undefined;
      if (!route) continue;
      const ref = db.doc(`trips/${date}_${bus.id}_fromCampus`);
      if ((await ref.get()).exists) continue;
      const fare = route.get('guestFare');
      try {
        await ref.create({
          busId: bus.id,
          routeId,
          driverId: bus.get('driverId') ?? null,
          date,
          direction: 'fromCampus',
          status: 'scheduled',
          startedAt: null,
          endedAt: null,
          departsAt: Timestamp.fromDate(schedule.departsAt),
          bookingOpensAt: Timestamp.fromDate(schedule.bookingOpensAt),
          bookingClosesAt: Timestamp.fromDate(schedule.bookingClosesAt),
          capacity: typeof bus.get('capacity') === 'number' ? bus.get('capacity') : 0,
          passHolders: await countPassHolders(routeId, now),
          altHeld: 0,
          seatsBooked: 0,
          notRiding: 0,
          // Fixed when the trip is made, so a fare change does not alter
          // what a student was quoted.
          guestFare: typeof fare === 'number' ? fare : null,
        });
        created.push(ref.id);
      } catch (e) {
        if ((e as { code?: number }).code !== 6) throw e; // made by a parallel run
      }
    }
  }
  return created;
}

/** Hourly, so a changed opening time or a new bus is picked up the same day. */
export const createEveningTrips = onSchedule({ schedule: 'every 60 minutes', timeZone: TIME_ZONE }, async () => {
  const created = await scheduleEveningTrips(new Date());
  if (created.length) logger.info('Evening trips created', { created });
});

// ---------------------------------------------------------------------------
// Bookings

/** Gives back an unpaid or paid booking's seat. Reads, then writes. */
function releaseSeat(tx: Transaction, booking: DocumentSnapshot, status: 'cancelled' | 'expired') {
  tx.update(booking.ref, { status, endedAt: FieldValue.serverTimestamp() });
  tx.update(db.doc(`trips/${booking.get('tripId')}`), { seatsBooked: FieldValue.increment(-1) });
}

function expired(booking: DocumentSnapshot, now: Date): boolean {
  const until = booking.get('expiresAt') as Timestamp | undefined;
  return booking.get('status') === 'pendingPayment' && until !== undefined && until.toDate() <= now;
}

export type BookResult =
  | 'booked'
  | 'alreadyBooked'
  | 'full'
  | 'notOpen'
  | 'closed'
  | 'passCovers'
  | 'noGuestSeats'
  | 'badStop'
  | 'paymentsUnavailable';

/**
 * Book a seat on an evening trip, getting off at [stopId]. The seat is kept
 * for PAYMENT_MINUTES while the student pays.
 */
export const bookSeat = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (request.auth?.token.email_verified !== true) throw new HttpsError('permission-denied', 'Verify your email first.');
  const { tripId, stopId } = request.data ?? {};
  if (typeof tripId !== 'string' || typeof stopId !== 'string') throw new HttpsError('invalid-argument', 'Which bus and stop?');
  const now = new Date();
  const answer = (result: BookResult, extra: Record<string, unknown> = {}) => ({ result, ...extra });

  const [student, tripSnap] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`trips/${tripId}`).get()]);
  if (student.get('role') !== 'student') throw new HttpsError('permission-denied', 'Only students can book seats.');
  if (!tripSnap.exists || tripSnap.get('direction') !== 'fromCampus' || !tripSnap.get('bookingClosesAt')) {
    throw new HttpsError('not-found', 'No bookable evening bus.');
  }
  const status = tripSnap.get('status');
  const window = bookingWindow(now, tripSnap.get('bookingOpensAt').toDate(), tripSnap.get('bookingClosesAt').toDate());
  if (window === 'notYet') return answer('notOpen');
  if (window === 'closed' || (status !== 'scheduled' && status !== 'running')) return answer('closed');

  const routeId = tripSnap.get('routeId') as string;
  // Pass holders of this route ride free and already have a seat.
  if (student.get('routeId') === routeId && passIsCurrent({
    passValid: student.get('passValid') === true,
    passValidUntil: typeof student.get('passValidUntil') === 'string' ? student.get('passValidUntil') : null,
  }, now)) return answer('passCovers');
  const fare = tripSnap.get('guestFare');
  if (typeof fare !== 'number') return answer('noGuestSeats');
  const route = await db.doc(`routes/${routeId}`).get();
  const stopIds = (route.get('stopIds') as string[] | undefined) ?? [];
  // Evening buses leave campus (the last stop) and drop along the way.
  if (!stopIds.includes(stopId) || stopId === stopIds.at(-1)) return answer('badStop');

  const keys = razorpayKeys();
  const mode = fare === 0 ? 'free' : demoPayments() ? 'demo' : keys ? 'razorpay' : null;
  if (!mode) return answer('paymentsUnavailable');

  const bookingId = bookingIdFor(tripId, uid);
  const bookingRef = db.doc(`bookings/${bookingId}`);
  const tripRef = tripSnap.ref;
  const result = await db.runTransaction(async (tx): Promise<BookResult> => {
    const [trip, existing] = await Promise.all([tx.get(tripRef), tx.get(bookingRef)]);
    if (existing.exists && holdsSeat(existing.get('status')) && !expired(existing, now)) return 'alreadyBooked';
    const free = spareSeats({
      capacity: trip.get('capacity') ?? 0,
      passHolders: trip.get('passHolders') ?? 0,
      notRiding: trip.get('notRiding') ?? 0,
      altHeld: trip.get('altHeld') ?? 0,
      seatsBooked: trip.get('seatsBooked') ?? 0,
    });
    // An unpaid booking that timed out gives its seat to this new one.
    const reusesSeat = existing.exists && expired(existing, now);
    if (!reusesSeat && free <= 0) return 'full';
    const confirmed = mode === 'free';
    tx.set(bookingRef, {
      tripId,
      uid,
      name: String(student.get('name') ?? ''),
      routeId,
      busId: trip.get('busId'),
      date: trip.get('date'),
      departsAt: trip.get('departsAt'),
      stopId,
      fare,
      status: confirmed ? 'confirmed' : 'pendingPayment',
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(now.getTime() + PAYMENT_MINUTES * 60_000),
      ...(confirmed ? { ticketToken: newTicketToken(), paidAt: FieldValue.serverTimestamp() } : {}),
      payment: { mode },
    });
    if (!reusesSeat) tx.update(tripRef, { seatsBooked: FieldValue.increment(1) });
    return 'booked';
  });
  if (result !== 'booked') return answer(result, result === 'alreadyBooked' ? { bookingId } : {});

  if (mode === 'razorpay') {
    try {
      const orderId = await razorpayOrder(keys!, fare, bookingId);
      // Kept so the app can reopen checkout if the student comes back to pay.
      await bookingRef.update({ 'payment.orderId': orderId, 'payment.keyId': keys!.keyId, 'payment.amountPaise': Math.round(fare * 100) });
      return answer('booked', { bookingId, fare, payment: { mode, keyId: keys!.keyId, orderId, amountPaise: Math.round(fare * 100) } });
    } catch (e) {
      logger.error('Razorpay order failed', e);
      await db.runTransaction(async (tx) => {
        const booking = await tx.get(bookingRef);
        if (booking.get('status') === 'pendingPayment') releaseSeat(tx, booking, 'cancelled');
      });
      return answer('paymentsUnavailable');
    }
  }
  return answer('booked', { bookingId, fare, payment: { mode } });
});

export type PayResult = 'confirmed' | 'expired' | 'invalidPayment' | 'notPending';

/** The student paid: check the proof, then issue the ticket. */
export const payBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { bookingId, demo, razorpayPaymentId, razorpaySignature } = request.data ?? {};
  if (typeof bookingId !== 'string') throw new HttpsError('invalid-argument', 'Which booking?');
  const now = new Date();
  const ref = db.doc(`bookings/${bookingId}`);
  const result = await db.runTransaction(async (tx): Promise<PayResult> => {
    const booking = await tx.get(ref);
    if (!booking.exists || booking.get('uid') !== uid) throw new HttpsError('not-found', 'No such booking.');
    if (booking.get('status') === 'confirmed') return 'confirmed';
    if (booking.get('status') !== 'pendingPayment') return 'notPending';
    if (expired(booking, now)) {
      releaseSeat(tx, booking, 'expired');
      return 'expired';
    }
    const mode = booking.get('payment.mode');
    let payment: Record<string, unknown>;
    if (mode === 'demo' && demo === true && demoPayments()) {
      payment = { mode };
    } else if (mode === 'razorpay' && typeof razorpayPaymentId === 'string' && typeof razorpaySignature === 'string') {
      const keys = razorpayKeys();
      const orderId = booking.get('payment.orderId');
      if (!keys || typeof orderId !== 'string' || !razorpaySignatureValid(orderId, razorpayPaymentId, razorpaySignature, keys.keySecret)) {
        return 'invalidPayment';
      }
      payment = { mode, orderId, paymentId: razorpayPaymentId };
    } else {
      return 'invalidPayment';
    }
    tx.update(ref, { status: 'confirmed', paidAt: FieldValue.serverTimestamp(), ticketToken: newTicketToken(), payment });
    return 'confirmed';
  });
  return { result };
});

/**
 * The student no longer wants an unpaid booking. Paid seats are refunded by
 * the transport office, so they are not cancelled here.
 */
export const cancelBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const bookingId = request.data?.bookingId;
  if (typeof bookingId !== 'string') throw new HttpsError('invalid-argument', 'Which booking?');
  const result = await db.runTransaction(async (tx) => {
    const booking = await tx.get(db.doc(`bookings/${bookingId}`));
    if (!booking.exists || booking.get('uid') !== uid) throw new HttpsError('not-found', 'No such booking.');
    if (booking.get('status') === 'confirmed') return 'paid';
    if (booking.get('status') !== 'pendingPayment') return 'none';
    releaseSeat(tx, booking, 'cancelled');
    return 'cancelled';
  });
  return { result };
});

/** Unpaid bookings past their time give their seats back. Safe to run twice. */
export async function expireUnpaidBookings(now: Date): Promise<number> {
  const due = await db.collection('bookings')
    .where('status', '==', 'pendingPayment')
    .where('expiresAt', '<=', Timestamp.fromDate(now))
    .get();
  let count = 0;
  for (const doc of due.docs) {
    const released = await db.runTransaction(async (tx) => {
      const booking = await tx.get(doc.ref);
      if (!expired(booking, now)) return false;
      releaseSeat(tx, booking, 'expired');
      return true;
    });
    if (released) count++;
  }
  return count;
}

export const expireBookings = onSchedule({ schedule: 'every 5 minutes', timeZone: TIME_ZONE }, async () => {
  const count = await expireUnpaidBookings(new Date());
  if (count) logger.info('Unpaid bookings expired', { count });
});
