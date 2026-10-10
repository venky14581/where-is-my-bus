import { createHmac } from 'node:crypto';

import { describe, expect, test } from 'vitest';

import {
  DEFAULT_BOOKING,
  bookingIdFor,
  bookingSettingsOf,
  bookingWindow,
  dayAfter,
  dayBefore,
  eveningSchedule,
  holdsSeat,
  parseTicketCode,
  razorpaySignatureValid,
  spareSeats,
  ticketCode,
} from './booking.js';

describe('booking settings', () => {
  test('fills anything missing or malformed with the planning defaults', () => {
    expect(bookingSettingsOf(undefined)).toEqual(DEFAULT_BOOKING);
    expect(bookingSettingsOf({ opensAt: '19:00', closesMinutesBefore: 20, eveningDepartsAt: '5pm' })).toEqual({
      opensAt: '19:00', closesMinutesBefore: 20, eveningDepartsAt: '16:30',
    });
  });
});

describe('the booking window', () => {
  test('opens the evening before and closes before departure, on the campus clock', () => {
    const s = eveningSchedule('2026-10-12', { opensAt: '18:00', closesMinutesBefore: 30, eveningDepartsAt: '16:30' });
    expect(s.bookingOpensAt.toISOString()).toBe('2026-10-11T12:30:00.000Z'); // 18:00 IST on the 11th
    expect(s.departsAt.toISOString()).toBe('2026-10-12T11:00:00.000Z'); // 16:30 IST
    expect(s.bookingClosesAt.toISOString()).toBe('2026-10-12T10:30:00.000Z'); // 16:00 IST
    expect(bookingWindow(new Date('2026-10-11T12:29:59Z'), s.bookingOpensAt, s.bookingClosesAt)).toBe('notYet');
    expect(bookingWindow(new Date('2026-10-11T12:30:00Z'), s.bookingOpensAt, s.bookingClosesAt)).toBe('open');
    expect(bookingWindow(new Date('2026-10-12T10:30:00Z'), s.bookingOpensAt, s.bookingClosesAt)).toBe('closed');
  });

  test('dates step across month ends', () => {
    expect(dayBefore('2026-11-01')).toBe('2026-10-31');
    expect(dayAfter('2026-12-31')).toBe('2027-01-01');
  });
});

describe('seats', () => {
  test('pass holders first; missed-bus holds and guests share the rest', () => {
    expect(spareSeats({ capacity: 50, passHolders: 40 })).toBe(10);
    expect(spareSeats({ capacity: 50, passHolders: 40, altHeld: 2, seatsBooked: 7 })).toBe(1);
    expect(spareSeats({ capacity: 50, passHolders: 55, seatsBooked: 0 })).toBe(0);
    // Pass holders not riding free their seats, never more than they hold.
    expect(spareSeats({ capacity: 50, passHolders: 48, notRiding: 3, seatsBooked: 4 })).toBe(1);
    expect(spareSeats({ capacity: 50, passHolders: 2, notRiding: 5 })).toBe(50);
    expect(['pendingPayment', 'confirmed', 'cancelled', 'expired', 'used'].filter(holdsSeat)).toEqual(['pendingPayment', 'confirmed']);
  });
});

describe('tickets', () => {
  test('a ticket code names its booking and carries a token', () => {
    const id = bookingIdFor('2026-10-12_bus-01_fromCampus', 'student-demo');
    const code = ticketCode(id, 'abc_DEF-123');
    expect(code).toBe('WIMBT1.2026-10-12_bus-01_fromCampus_student-demo.abc_DEF-123');
    expect(parseTicketCode(code)).toEqual({ bookingId: id, token: 'abc_DEF-123' });
    expect(parseTicketCode('WIMB1.student-demo.1.x')).toBeNull();
    expect(parseTicketCode('WIMBT1.only')).toBeNull();
    expect(parseTicketCode('WIMBT1.bad/id.token')).toBeNull();
  });
});

test('Razorpay payment signatures', () => {
  const secret = 'test_secret';
  const signature = createHmac('sha256', secret).update('order_1|pay_1').digest('hex');
  expect(razorpaySignatureValid('order_1', 'pay_1', signature, secret)).toBe(true);
  expect(razorpaySignatureValid('order_1', 'pay_2', signature, secret)).toBe(false);
  expect(razorpaySignatureValid('order_1', 'pay_1', 'short', secret)).toBe(false);
});
