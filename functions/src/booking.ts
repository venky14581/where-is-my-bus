// Evening seat booking: the rules, kept free of Firebase so they can be unit
// tested. Used by bookings.ts and boarding.ts.

import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/** The office's booking settings (`settings/booking`), with the planning defaults. */
export interface BookingSettings {
  /** Booking opens at this time (HH:MM, campus clock) the evening before. */
  opensAt: string;
  /** And closes this many minutes before the bus leaves campus. */
  closesMinutesBefore: number;
  /** When evening buses leave campus (HH:MM). */
  eveningDepartsAt: string;
}

export const DEFAULT_BOOKING: BookingSettings = { opensAt: '18:00', closesMinutesBefore: 30, eveningDepartsAt: '16:30' };

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export function bookingSettingsOf(raw: Record<string, unknown> | undefined): BookingSettings {
  const time = (value: unknown, fallback: string) => (typeof value === 'string' && HHMM.test(value) ? value : fallback);
  const minutes = raw?.closesMinutesBefore;
  return {
    opensAt: time(raw?.opensAt, DEFAULT_BOOKING.opensAt),
    closesMinutesBefore: typeof minutes === 'number' && minutes >= 0 && minutes <= 240 ? minutes : DEFAULT_BOOKING.closesMinutesBefore,
    eveningDepartsAt: time(raw?.eveningDepartsAt, DEFAULT_BOOKING.eveningDepartsAt),
  };
}

/** A campus-clock time on a date, as an instant. India has no daylight saving. */
export function campusTime(date: string, hhmm: string): Date {
  return new Date(`${date}T${hhmm}:00+05:30`);
}

/** The date before [date] (YYYY-MM-DD). */
export function dayBefore(date: string): string {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

export function dayAfter(date: string): string {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

/** When the evening bus on [date] leaves, and when booking for it opens and closes. */
export function eveningSchedule(date: string, settings: BookingSettings) {
  const departsAt = campusTime(date, settings.eveningDepartsAt);
  return {
    departsAt,
    bookingOpensAt: campusTime(dayBefore(date), settings.opensAt),
    bookingClosesAt: new Date(departsAt.getTime() - settings.closesMinutesBefore * 60_000),
  };
}

export type WindowState = 'notYet' | 'open' | 'closed';

export function bookingWindow(now: Date, opensAt: Date, closesAt: Date): WindowState {
  if (now < opensAt) return 'notYet';
  return now < closesAt ? 'open' : 'closed';
}

/**
 * Seats nobody else has a claim on. The route's pass holders come first,
 * except those who said they are not riding, then riders from other routes
 * who missed their bus and guests who booked.
 */
export function spareSeats(trip: {
  capacity: number;
  passHolders: number;
  notRiding?: number;
  altHeld?: number;
  seatsBooked?: number;
}): number {
  const keep = Math.max(0, trip.passHolders - (trip.notRiding ?? 0));
  return Math.max(0, trip.capacity - keep - (trip.altHeld ?? 0) - (trip.seatsBooked ?? 0));
}

/** An unpaid booking keeps its seat this long. */
export const PAYMENT_MINUTES = 10;

/** A booking keeps a seat while unpaid (and not yet timed out) or paid. */
export function holdsSeat(status: unknown): boolean {
  return status === 'pendingPayment' || status === 'confirmed';
}

/** One booking per student per trip, so asking twice cannot take two seats. */
export const bookingIdFor = (tripId: string, uid: string) => `${tripId}_${uid}`;

// A ticket QR: WIMBT1.<bookingId>.<token>. The token is random and kept on
// the booking, so a ticket cannot be made up. One scan only.
const TICKET_PREFIX = 'WIMBT1';

export function newTicketToken(): string {
  return randomBytes(12).toString('base64url');
}

export const ticketCode = (bookingId: string, token: string) => `${TICKET_PREFIX}.${bookingId}.${token}`;

export function parseTicketCode(code: unknown): { bookingId: string; token: string } | null {
  if (typeof code !== 'string' || !code.startsWith(`${TICKET_PREFIX}.`)) return null;
  const body = code.slice(TICKET_PREFIX.length + 1);
  const last = body.lastIndexOf('.');
  if (last <= 0 || last === body.length - 1) return null;
  const bookingId = body.slice(0, last);
  if (!/^[\w-]+$/.test(bookingId)) return null;
  return { bookingId, token: body.slice(last + 1) };
}

export function sameToken(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

/**
 * Razorpay's proof that an order was paid: HMAC-SHA256 of
 * "<order_id>|<payment_id>" with the key secret, hex.
 */
export function razorpaySignatureValid(orderId: string, paymentId: string, signature: string, keySecret: string): boolean {
  const expected = createHmac('sha256', keySecret).update(`${orderId}|${paymentId}`).digest('hex');
  return sameToken(expected, signature);
}
