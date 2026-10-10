// Module 3 (driver trip and GPS), with the data Modules 4 (live map) and 5
// (arrival time) read. The screens themselves are covered by flutter test.
// Screen-off tracking needs an Android phone and is not checked here.
import { get, goOffline, onDisconnect, ref, serverTimestamp as rtdbNow, set, update } from 'firebase/database';
import { Timestamp, doc, getDoc, getDocs, collection, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { SEEDED, admin, campusDate, campusTime, closeAll, errorCode, resetAndSeed, signIn, waitFor } from './support.js';

beforeAll(resetAndSeed, 60_000);
afterAll(closeAll);

const today = campusDate();
const TRIP = `${today}_bus-01_toCampus`;
const newTrip = (overrides = {}) => ({
  busId: 'bus-01', routeId: 'cbe-gandhipuram', driverId: SEEDED.drv001.uid, date: today,
  direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null, ...overrides,
});
const position = (overrides = {}) => ({
  lat: 10.9946, lng: 76.9618, speed: 8, updatedAt: rtdbNow(), tripId: TRIP, status: 'running', ...overrides,
});

let driver;
beforeAll(async () => {
  driver = await signIn(SEEDED.drv001);
});

test('only the assigned driver starts a trip on the bus', async () => {
  const other = await signIn(SEEDED.drv002);
  expect(await errorCode(setDoc(doc(other.db, `trips/${TRIP}`), newTrip({ driverId: other.uid })))).toBe('permission-denied');
  expect(await errorCode(setDoc(doc(driver.db, `trips/${today}_bus-01_wrong`), newTrip()))).toBe('permission-denied');
  await setDoc(doc(driver.db, `trips/${TRIP}`), newTrip());
  expect((await admin.db.doc(`trips/${TRIP}`).get()).get('status')).toBe('running');
});

test('the driver sends the latest position; nobody else can, and bad values are refused', async () => {
  await set(ref(driver.rtdb, 'live/bus-01'), position());
  const live = (await admin.rtdb.ref('live/bus-01').get()).val();
  expect(live).toMatchObject({ lat: 10.9946, lng: 76.9618, tripId: TRIP, status: 'running' });
  expect(Math.abs(live.updatedAt - Date.now())).toBeLessThan(10_000);

  // Only the latest point is kept: a new one replaces it.
  await set(ref(driver.rtdb, 'live/bus-01'), position({ lat: 10.9886, lng: 76.962 }));
  expect((await admin.rtdb.ref('live/bus-01/lat').get()).val()).toBe(10.9886);

  const other = await signIn(SEEDED.drv002);
  expect(await errorCode(set(ref(other.rtdb, 'live/bus-01'), position()))).toMatch(/permission/i);
  expect(await errorCode(set(ref(driver.rtdb, 'live/bus-01'), position({ lat: 200 })))).toMatch(/permission/i);
  expect(await errorCode(set(ref(driver.rtdb, 'live/bus-01'), position({ speed: 100 })))).toMatch(/permission/i);
});

test('a verified student sees the live position (Module 4)', async () => {
  const s = await signIn(SEEDED.student);
  expect((await get(ref(s.rtdb, 'live/bus-01'))).val().tripId).toBe(TRIP);
});

test('stop times are recorded for stops on the route only, and students read them (Module 5)', async () => {
  const arrivedAt = Timestamp.fromDate(campusTime(today, '07:10'));
  await setDoc(doc(driver.db, `trips/${TRIP}/stopTimes/town-hall`), { stopId: 'town-hall', arrivedAt, recordedAt: serverTimestamp() });
  expect(await errorCode(setDoc(doc(driver.db, `trips/${TRIP}/stopTimes/selvapuram`), { stopId: 'selvapuram', arrivedAt, recordedAt: serverTimestamp() })))
    .toBe('permission-denied');
  const s = await signIn(SEEDED.student);
  const times = await getDocs(collection(s.db, `trips/${TRIP}/stopTimes`));
  expect(times.docs.map((d) => d.id)).toEqual(['town-hall']);
});

test('when the driver loses connection the bus shows offline', async () => {
  const phone = await signIn(SEEDED.drv001);
  const live = ref(phone.rtdb, 'live/bus-01');
  await set(live, position());
  await onDisconnect(live).update({ status: 'offline' });
  goOffline(phone.rtdb);
  await waitFor(async () => (await admin.rtdb.ref('live/bus-01/status').get()).val() === 'offline', { what: 'offline status' });
});

test('the driver ends the trip and can resume it', async () => {
  await updateDoc(doc(driver.db, `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() });
  await update(ref(driver.rtdb, 'live/bus-01'), { status: 'ended', updatedAt: rtdbNow(), tripId: TRIP });
  const ended = (await admin.db.doc(`trips/${TRIP}`).get()).data();
  expect(ended.status).toBe('ended');
  expect(ended.endedAt).toBeTruthy();
  expect((await admin.rtdb.ref('live/bus-01/status').get()).val()).toBe('ended');
  await updateDoc(doc(driver.db, `trips/${TRIP}`), { status: 'running', endedAt: null });
  expect((await getDoc(doc(driver.db, `trips/${TRIP}`))).get('status')).toBe('running');
  const other = await signIn(SEEDED.drv002);
  expect(await errorCode(updateDoc(doc(other.db, `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() }))).toBe('permission-denied');
});
