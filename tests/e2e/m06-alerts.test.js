// Module 6: alerts. On the emulators every push is written to pushLog.
// Delivery to a real phone needs a real project and is not checked here.
import { Timestamp, addDoc, collection, doc, serverTimestamp, setDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { SEEDED, admin, campusDate, campusTime, closeAll, errorCode, makeStudent, resetAndSeed, signIn, sleep, waitFor } from './support.js';

const today = campusDate();
const TRIP = `${today}_bus-01_toCampus`;

let driver;
beforeAll(async () => {
  await resetAndSeed();
  // A: default settings, 3 stops out. B: delays and breakdowns switched off.
  await makeStudent('rider-a', { routeId: 'cbe-gandhipuram', stopId: 'kuniyamuthur' });
  await makeStudent('rider-b', { routeId: 'cbe-gandhipuram', stopId: 'gandhipuram', alerts: { delays: false } });
  driver = await signIn(SEEDED.drv001);
}, 60_000);
afterAll(closeAll);

const pushes = async (kind, uid) =>
  (await admin.db.collection('pushLog').where('kind', '==', kind).where('uid', '==', uid).get()).size;
const feed = async (kind) => (await admin.db.collection('alerts').where('kind', '==', kind).get()).size;

const reach = (stopId, hhmm) => setDoc(doc(driver.db, `trips/${TRIP}/stopTimes/${stopId}`), {
  stopId, arrivedAt: Timestamp.fromDate(campusTime(today, hhmm)), recordedAt: serverTimestamp(),
});

test('starting a trip tells the route once', async () => {
  await setDoc(doc(driver.db, `trips/${TRIP}`), {
    busId: 'bus-01', routeId: 'cbe-gandhipuram', driverId: driver.uid, date: today,
    direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null,
  });
  await waitFor(async () => (await pushes('tripStarted', 'rider-a')) && (await pushes('tripStarted', 'rider-b')), { what: 'trip-started pushes' });
  await sleep(2000);
  expect(await pushes('tripStarted', 'rider-a')).toBe(1);
  expect(await pushes('tripStarted', 'rider-b')).toBe(1);
  expect(await feed('tripStarted')).toBe(1);
});

test('reaching a stop 11 minutes late: approaching for A, one delay alert, no push to B', async () => {
  await reach('town-hall', '07:21'); // timetable 07:10
  await waitFor(async () => (await pushes('approaching', 'rider-a')) && (await feed('delay')), { what: 'approaching and delay' });
  await waitFor(async () => pushes('delay', 'rider-a'), { what: 'delay push' });
  expect(await pushes('delay', 'rider-b')).toBe(0);
  expect(await pushes('approaching', 'rider-b')).toBe(0); // their stop is behind the bus
});

test('the next stop, still 11 minutes late, sends no second alert', async () => {
  await reach('ukkadam', '07:26'); // timetable 07:15
  await sleep(3000);
  expect(await feed('delay')).toBe(1);
  expect(await pushes('delay', 'rider-a')).toBe(1);
  expect(await pushes('approaching', 'rider-a')).toBe(1);
});

test("a breakdown report reaches the list and riders who want it; students can't report", async () => {
  await addDoc(collection(driver.db, `trips/${TRIP}/reports`), { type: 'breakdown', createdAt: serverTimestamp() });
  await waitFor(async () => (await feed('breakdown')) && (await pushes('breakdown', 'rider-a')), { what: 'breakdown alert' });
  expect(await pushes('breakdown', 'rider-b')).toBe(0);
  const student = await signIn(SEEDED.student);
  expect(await errorCode(addDoc(collection(student.db, `trips/${TRIP}/reports`), { type: 'late', createdAt: serverTimestamp() })))
    .toBe('permission-denied');
});

test('an announcement to all reaches every student; only the office announces', async () => {
  const office = await signIn(SEEDED.office);
  const notice = { routeId: null, title: 'Holiday on Monday', body: 'No buses run.', createdAt: serverTimestamp(), createdBy: office.uid };
  await addDoc(collection(office.db, 'announcements'), notice);
  for (const uid of ['rider-a', 'rider-b', SEEDED.student.uid]) {
    await waitFor(async () => (await pushes('announcement', uid)) === 1, { what: `announcement to ${uid}` });
  }
  const student = await signIn(SEEDED.student);
  expect(await errorCode(addDoc(collection(student.db, 'announcements'), { ...notice, createdBy: student.uid }))).toBe('permission-denied');
});

test('server-only paths stay closed to clients', async () => {
  const student = await signIn(SEEDED.student);
  expect(await errorCode(setDoc(doc(student.db, 'pushLog/x'), { a: 1 }))).toBe('permission-denied');
  expect(await errorCode(setDoc(doc(student.db, 'alerts/x'), { a: 1 }))).toBe('permission-denied');
  expect(await errorCode(setDoc(doc(student.db, 'functionRuns/x'), { a: 1 }))).toBe('permission-denied');
});
