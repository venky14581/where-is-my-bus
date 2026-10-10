// Module 10: evening seat booking. The scheduled functions do not run on the
// emulators (no Pub/Sub emulator), so their work is called directly here.
// Payments use the emulator-only demo mode; Razorpay needs real test keys.
import { doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { SEEDED, addDays, admin, campusDate, campusTime, closeAll, errorCode, makeStudent, passUntil, resetAndSeed, signIn, waitFor } from './support.js';
import { expireUnpaidBookings, scheduleEveningTrips } from '../../functions/lib/bookings.js';

const today = campusDate();
const tomorrow = addDays(today, 1);
// Tomorrow's evening trips are always made, whatever the time of day.
const T1 = `${tomorrow}_bus-01_fromCampus`; // Gandhipuram, fare 40
const T2 = `${tomorrow}_bus-02_fromCampus`; // R.S. Puram, fare 30
const T3 = `${tomorrow}_bus-03_fromCampus`; // Palakkad, no guest seats
const trip = (id) => admin.db.doc(`trips/${id}`);
const seatsBooked = async (id) => (await trip(id).get()).get('seatsBooked');
const minutesFromNow = (m) => new Date(Date.now() + m * 60_000);
const openWindow = (id) => trip(id).update({ bookingOpensAt: minutesFromNow(-60), bookingClosesAt: minutesFromNow(60) });

const s = {};
let created;
beforeAll(async () => {
  await resetAndSeed();
  await admin.db.doc('routes/cbe-gandhipuram').update({ guestFare: 40 });
  await admin.db.doc('routes/cbe-rs-puram').update({ guestFare: 30 });
  s.host = await signIn(SEEDED.student); // a hosteller: no daily route
  s.pavi = await makeStudent('pavi', { routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: true, passValidUntil: passUntil() });
  s.riya = await makeStudent('riya', { routeId: 'cbe-rs-puram', stopId: 'selvapuram', passValid: true, passValidUntil: passUntil() });
  s.xavi = await makeStudent('xavi');
  s.yash = await makeStudent('yash');
  created = await scheduleEveningTrips(new Date());
  for (const id of [T1, T2, T3]) await openWindow(id);
}, 90_000);
afterAll(closeAll);

const book = (who, tripId, stopId) => s[who].call('bookSeat', { tripId, stopId });

test('a hosteller says they take no daily bus', async () => {
  await updateDoc(doc(s.host.db, 'users/student-demo'), { routeId: null, stopId: null, dailyRider: false });
  expect(await errorCode(updateDoc(doc(s.host.db, 'users/student-demo'), { dailyRider: 'no' }))).toBe('permission-denied');
});

test('evening trips are made for every bus, once, with the booking window', async () => {
  expect(created).toEqual(expect.arrayContaining([T1, T2, T3]));
  const todayStillToLeave = Date.now() < campusTime(today, '16:30').getTime();
  expect(created.length).toBe(todayStillToLeave ? 6 : 3);
  expect(await scheduleEveningTrips(new Date())).toEqual([]);
  // Made fresh to check the window the scheduler writes, before openWindow.
  await trip(T3).delete();
  await scheduleEveningTrips(new Date());
  const t3 = (await trip(T3).get()).data();
  expect(t3).toMatchObject({ status: 'scheduled', direction: 'fromCampus', capacity: 45, seatsBooked: 0, altHeld: 0, guestFare: null });
  expect(t3.departsAt.toDate()).toEqual(campusTime(tomorrow, '16:30'));
  expect(t3.bookingOpensAt.toDate()).toEqual(campusTime(today, '18:00'));
  expect(t3.bookingClosesAt.toDate()).toEqual(campusTime(tomorrow, '16:00'));
  await openWindow(T3);
  const t1 = (await trip(T1).get()).data();
  expect(t1).toMatchObject({ guestFare: 40, passHolders: 1 });
});

test('the server refuses what the app must not allow', async () => {
  expect((await book('pavi', T1, 'ukkadam')).result).toBe('passCovers');
  expect((await book('host', T1, 'campus')).result).toBe('badStop');
  expect((await book('host', T1, 'selvapuram')).result).toBe('badStop');
  expect((await book('host', T3, 'walayar')).result).toBe('noGuestSeats');
  await trip(T2).update({ bookingOpensAt: minutesFromNow(30) });
  expect((await book('host', T2, 'selvapuram')).result).toBe('notOpen');
  await trip(T2).update({ bookingOpensAt: minutesFromNow(-60), bookingClosesAt: minutesFromNow(-1) });
  expect((await book('host', T2, 'selvapuram')).result).toBe('closed');
  await openWindow(T2);
  const driver = await signIn(SEEDED.drv001);
  expect(await errorCode(driver.call('bookSeat', { tripId: T1, stopId: 'ukkadam' }))).toBe('functions/permission-denied');
  expect(await seatsBooked(T1)).toBe(0);
});

let ticket;
test('book, pay, ticket: one seat however often the student asks', async () => {
  await admin.db.doc('routes/cbe-gandhipuram').update({ guestFare: 99 }); // the trip keeps the fare it was made with
  const booked = await book('host', T1, 'ukkadam');
  expect(booked).toMatchObject({ result: 'booked', fare: 40, payment: { mode: 'demo' } });
  expect((await book('host', T1, 'ukkadam')).result).toBe('alreadyBooked');
  expect(await seatsBooked(T1)).toBe(1);
  expect(await errorCode(s.xavi.call('payBooking', { bookingId: booked.bookingId, demo: true }))).toBe('functions/not-found');
  expect((await s.host.call('payBooking', { bookingId: booked.bookingId })).result).toBe('invalidPayment');
  expect((await s.host.call('payBooking', { bookingId: booked.bookingId, demo: true })).result).toBe('confirmed');
  const mine = await getDoc(doc(s.host.db, `bookings/${booked.bookingId}`));
  expect(mine.data()).toMatchObject({ status: 'confirmed', fare: 40, stopId: 'ukkadam' });
  ticket = `WIMBT1.${booked.bookingId}.${mine.get('ticketToken')}`;
  expect((await s.host.call('cancelBooking', { bookingId: booked.bookingId })).result).toBe('paid');
});

test('cancelling or not paying in time gives the seat back', async () => {
  const first = await book('host', T2, 'selvapuram');
  expect((await s.host.call('cancelBooking', { bookingId: first.bookingId })).result).toBe('cancelled');
  expect(await seatsBooked(T2)).toBe(0);
  const again = await book('host', T2, 'selvapuram');
  expect(again.result).toBe('booked');
  await admin.db.doc(`bookings/${again.bookingId}`).update({ expiresAt: minutesFromNow(-1) });
  expect(await expireUnpaidBookings(new Date())).toBe(1);
  expect(await expireUnpaidBookings(new Date())).toBe(0);
  expect((await admin.db.doc(`bookings/${again.bookingId}`).get()).get('status')).toBe('expired');
  expect(await seatsBooked(T2)).toBe(0);
  expect((await s.host.call('payBooking', { bookingId: again.bookingId, demo: true })).result).toBe('notPending');
});

let otherTicket;
test("two students race for the last seat: one gets it; pass holders' seats are never sold", async () => {
  expect((await book('riya', T2, 'selvapuram')).result).toBe('passCovers');
  await trip(T2).update({ passHolders: 49 }); // 50 seats, 1 left
  const results = await Promise.all([book('xavi', T2, 'selvapuram'), book('yash', T2, 'rs-puram')]);
  expect(results.map((r) => r.result).sort()).toEqual(['booked', 'full']);
  expect(await seatsBooked(T2)).toBe(1);
  expect((await book('host', T2, 'selvapuram')).result).toBe('full');
  const winner = results[0].result === 'booked' ? 'xavi' : 'yash';
  const won = results.find((r) => r.result === 'booked');
  await s[winner].call('payBooking', { bookingId: won.bookingId, demo: true });
  otherTicket = `WIMBT1.${won.bookingId}.${(await admin.db.doc(`bookings/${won.bookingId}`).get()).get('ticketToken')}`;
});

test('the driver starts the scheduled trip; riders are told and booking stays open', async () => {
  const driver = await signIn(SEEDED.drv001);
  await updateDoc(doc(driver.db, `trips/${T1}`), { status: 'running', endedAt: null });
  await waitFor(async () => (await trip(T1).get()).get('startedAt'), { what: 'startedAt' });
  await waitFor(async () => !(await admin.db.collection('pushLog').where('kind', '==', 'tripStarted').where('uid', '==', 'pavi').get()).empty,
    { what: 'trip-started push' });
  expect((await book('riya', T1, 'town-hall')).result).toBe('booked');
});

test('a ticket boards once, on its own bus only; forged tickets fail', async () => {
  const driver = await signIn(SEEDED.drv001);
  const scan = (code) => driver.call('scanPass', { tripId: T1, code }).then((r) => r.result);
  expect(await scan(ticket.replace(/\.[^.]+$/, '.forged'))).toBe('invalidCode');
  expect(await scan(otherTicket)).toBe('wrongTrip');
  expect(await scan(ticket)).toBe('boarded');
  expect(await scan(ticket)).toBe('ticketUsed');
  expect((await admin.db.doc(`trips/${T1}/boardings/student-demo`).get()).get('type')).toBe('guest');
});

test('a booking is readable by its student and the office only, and written by nobody', async () => {
  const id = `${T1}_student-demo`;
  expect((await getDoc(doc(s.host.db, `bookings/${id}`))).get('status')).toBe('used');
  expect(await errorCode(getDoc(doc(s.xavi.db, `bookings/${id}`)))).toBe('permission-denied');
  const office = await signIn(SEEDED.office);
  expect((await getDoc(doc(office.db, `bookings/${id}`))).exists()).toBe(true);
  expect(await errorCode(setDoc(doc(s.xavi.db, `bookings/${T1}_xavi`), { uid: 'xavi', tripId: T1, status: 'confirmed', createdAt: serverTimestamp() })))
    .toBe('permission-denied');
});
