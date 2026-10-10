// Module 7: office dashboard. The dashboard's screens have their own tests;
// this checks the server side they rely on.
import { ref, serverTimestamp as rtdbNow, set } from 'firebase/database';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { SEEDED, admin, closeAll, errorCode, resetAndSeed, signIn, waitFor } from './support.js';

let office;
beforeAll(async () => {
  await resetAndSeed();
  office = await signIn(SEEDED.office);
}, 60_000);
afterAll(closeAll);

const drv003 = { email: 'drv003@drivers.whereismybus.invalid', password: '730214' };
let drv003Uid;

test('the office adds driver DRV003, who signs in with that PIN', async () => {
  const made = await office.call('createDriver', { driverId: 'drv003', name: 'Kannan R', pin: '730214' });
  expect(made.driverId).toBe('DRV003');
  drv003Uid = made.uid;
  expect((await admin.db.doc(`users/${made.uid}`).get()).data()).toMatchObject({ role: 'driver', driverId: 'DRV003', language: null });
  expect((await signIn(drv003)).uid).toBe(made.uid);
  expect(await errorCode(signIn({ ...drv003, password: '111111' }))).toMatch(/auth\//);
  expect(await errorCode(office.call('createDriver', { driverId: 'DRV003', name: 'Again', pin: '123456' }))).toBe('functions/already-exists');
  expect(await errorCode(office.call('createDriver', { driverId: 'DRV004', name: 'Bad', pin: '12' }))).toBe('functions/invalid-argument');
});

test('only the office creates drivers and resets PINs', async () => {
  const student = await signIn(SEEDED.student);
  expect(await errorCode(student.call('createDriver', { driverId: 'DRV005', name: 'X', pin: '123456' }))).toBe('functions/permission-denied');
  const driver = await signIn(SEEDED.drv001);
  expect(await errorCode(driver.call('setDriverPin', { uid: driver.uid, pin: '123456' }))).toBe('functions/permission-denied');
});

test('a new PIN replaces the old one', async () => {
  await office.call('setDriverPin', { uid: drv003Uid, pin: '551177' });
  expect(await errorCode(signIn(drv003))).toMatch(/auth\//);
  expect((await signIn({ ...drv003, password: '551177' })).uid).toBe(drv003Uid);
  drv003.password = '551177';
});

test('assigning DRV003 to a bus lets them send its position', async () => {
  await updateDoc(doc(office.db, 'buses/bus-02'), { driverId: drv003Uid });
  await waitFor(async () => (await admin.rtdb.ref('busDrivers/bus-02').get()).val() === drv003Uid, { what: 'busDrivers/bus-02' });
  const d = await signIn(drv003);
  await set(ref(d.rtdb, 'live/bus-02'), { lat: 11, lng: 76.95, updatedAt: rtdbNow(), tripId: 't', status: 'running' });
  // Unassigning takes the right away again.
  await updateDoc(doc(office.db, 'buses/bus-02'), { driverId: null });
  await waitFor(async () => (await admin.rtdb.ref('busDrivers/bus-02').get()).val() === null, { what: 'busDrivers/bus-02 removed' });
  expect(await errorCode(set(ref(d.rtdb, 'live/bus-02'), { lat: 11, lng: 76.95, updatedAt: rtdbNow(), tripId: 't', status: 'running' })))
    .toMatch(/permission/i);
});

test('booking window and guest fares save; bad routes and buses are refused', async () => {
  await setDoc(doc(office.db, 'settings/booking'), { opensAt: '18:00', closesMinutesBefore: 20, eveningDepartsAt: '16:30' });
  await updateDoc(doc(office.db, 'routes/cbe-rs-puram'), { guestFare: 35 });
  expect((await admin.db.doc('routes/cbe-rs-puram').get()).get('guestFare')).toBe(35);
  expect(await errorCode(updateDoc(doc(office.db, 'routes/cbe-rs-puram'), { guestFare: -5 }))).toBe('permission-denied');
  expect(await errorCode(updateDoc(doc(office.db, 'routes/cbe-rs-puram'), { stopIds: ['a'] }))).toBe('permission-denied');
  expect(await errorCode(updateDoc(doc(office.db, 'buses/bus-02'), { capacity: 0 }))).toBe('permission-denied');
  expect(await errorCode(updateDoc(doc(office.db, 'buses/bus-02'), { routeId: 'nowhere' }))).toBe('permission-denied');
  const student = await signIn(SEEDED.student);
  expect(await errorCode(setDoc(doc(student.db, 'settings/booking'), { opensAt: '00:00' }))).toBe('permission-denied');
});
