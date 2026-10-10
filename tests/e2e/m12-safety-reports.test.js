// Module 12: safety and reports. SOS, overspeed and off-route alerts, the
// parent's trip link, and the history the reports are built from.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

import { ref, serverTimestamp as rtdbNow, set } from 'firebase/database';
import { addDoc, collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { SEEDED, admin, anonymous, campusDate, closeAll, errorCode, makeStudent, resetAndSeed, signIn, waitFor } from './support.js';

const today = campusDate();
const TRIP = `${today}_bus-01_toCampus`;
const BUS_AT = { lat: 10.9886, lng: 76.962 }; // Ukkadam

let driver;
let student;
let office;

beforeAll(async () => {
  await resetAndSeed();
  driver = await signIn(SEEDED.drv001);
  office = await signIn(SEEDED.office);
  student = await makeStudent('asha', { routeId: 'cbe-gandhipuram', stopId: 'madukkarai' });
  await setDoc(doc(driver.db, `trips/${TRIP}`), {
    busId: 'bus-01', routeId: 'cbe-gandhipuram', driverId: driver.uid, date: today,
    direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null,
  });
  await set(ref(driver.rtdb, 'live/bus-01'), { ...BUS_AT, speed: 9, updatedAt: rtdbNow(), tripId: TRIP, status: 'running' });
}, 60_000);
afterAll(closeAll);

const alert = (id) => admin.db.doc(`safetyAlerts/${id}`).get().then((d) => d.data());

describe('SOS', () => {
  test('from the driver: the bus and where it is, to the office', async () => {
    expect((await driver.call('sendSos')).result).toBe('sent');
    const sos = await alert(`sos_${TRIP}_${driver.uid}`);
    expect(sos).toMatchObject({
      type: 'sos', status: 'open', busNumber: 'TN 37 AB 1201', routeName: 'Gandhipuram – Campus',
      fromRole: 'driver', fromName: 'Murugan S', driverName: 'Murugan S', ...BUS_AT,
    });
  });

  test("from a student on the route: the bus's location, never the student's", async () => {
    expect((await student.call('sendSos')).result).toBe('sent');
    const sos = await alert(`sos_${TRIP}_asha`);
    expect(sos).toMatchObject({ type: 'sos', fromRole: 'student', fromName: 'Student asha', ...BUS_AT });
    // Pressing again refreshes the same alert rather than adding another.
    await student.call('sendSos');
    expect((await admin.db.collection('safetyAlerts').where('fromUid', '==', 'asha').get()).size).toBe(1);
  });

  test('no running trip, nothing to send', async () => {
    expect((await (await signIn(SEEDED.drv002)).call('sendSos')).result).toBe('noTrip');
    const elsewhere = await makeStudent('ravi', { routeId: 'pkd-town', stopId: 'walayar' });
    expect((await elsewhere.call('sendSos')).result).toBe('noTrip');
  });
});

describe("events from the driver's phone", () => {
  test('overspeed and off-route each become one office alert', async () => {
    const speeding = await addDoc(collection(driver.db, `trips/${TRIP}/events`), {
      type: 'overspeed', ...BUS_AT, speedKmh: 72, limitKmh: 60, createdAt: serverTimestamp(),
    });
    const away = await addDoc(collection(driver.db, `trips/${TRIP}/events`), {
      type: 'offRoute', lat: 10.97, lng: 76.99, distanceM: 420, createdAt: serverTimestamp(),
    });
    const a = await waitFor(() => alert(`${TRIP}_${speeding.id}`), { what: 'overspeed alert' });
    expect(a).toMatchObject({ type: 'overspeed', status: 'open', busNumber: 'TN 37 AB 1201', details: { speedKmh: 72, limitKmh: 60 } });
    const b = await waitFor(() => alert(`${TRIP}_${away.id}`), { what: 'off-route alert' });
    expect(b).toMatchObject({ type: 'offRoute', details: { distanceM: 420 }, lat: 10.97 });
  });

  test("another driver can't report on this trip", async () => {
    const other = await signIn(SEEDED.drv002);
    expect(await errorCode(addDoc(collection(other.db, `trips/${TRIP}/events`), {
      type: 'overspeed', ...BUS_AT, speedKmh: 90, limitKmh: 60, createdAt: serverTimestamp(),
    }))).toBe('permission-denied');
  });
});

test('the office sees and acknowledges alerts; nobody else reads them', async () => {
  const open = await getDocs(query(collection(office.db, 'safetyAlerts'), where('status', '==', 'open')));
  expect(open.size).toBe(4); // two SOS, overspeed, off-route
  const first = open.docs[0];
  await updateDoc(first.ref, { status: 'acknowledged', acknowledgedBy: office.uid, acknowledgedAt: serverTimestamp() });
  expect((await alert(first.id)).status).toBe('acknowledged');
  expect(await errorCode(getDocs(collection(student.db, 'safetyAlerts')))).toBe('permission-denied');
  expect(await errorCode(getDoc(doc(driver.db, `safetyAlerts/${first.id}`)))).toBe('permission-denied');
});

describe("a parent's trip link", () => {
  let token;

  test('a student shares their running trip', async () => {
    const shared = await student.call('shareTrip');
    expect(shared.result).toBe('shared');
    token = shared.token;
    expect(token).toMatch(/^[\w-]{22}$/);
    expect(await errorCode(driver.call('shareTrip'))).toBe('functions/permission-denied');
    const noBus = await makeStudent('nila', { routeId: 'pkd-town', stopId: 'walayar' });
    expect((await noBus.call('shareTrip')).result).toBe('noTrip');
  });

  test('anyone with the link sees that one bus, the route and the stop, without signing in', async () => {
    const parent = anonymous();
    const view = await parent.call('viewSharedTrip', { token });
    expect(view).toMatchObject({
      result: 'ok', busNumber: 'TN 37 AB 1201', routeName: 'Gandhipuram – Campus', direction: 'toCampus',
      stopId: 'madukkarai', bus: BUS_AT, liveStatus: 'running',
    });
    expect(view.stops).toHaveLength(7);
    expect(view.path).toBeTruthy();
    expect(JSON.stringify(view)).not.toContain('asha'); // nothing about who shared it
    expect((await parent.call('viewSharedTrip', { token: 'x'.repeat(22) })).result).toBe('notFound');
    expect((await parent.call('viewSharedTrip', { token: '../../users' })).result).toBe('notFound');
  });

  test('the link stops working when the trip ends', async () => {
    await updateDoc(doc(driver.db, `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() });
    expect((await anonymous().call('viewSharedTrip', { token })).result).toBe('ended');
  });
});

test('past trips for the reports, without alerting anyone about them', async () => {
  await promisify(execFile)(process.execPath, ['scripts/seed-history.mjs', '--days', '7'], { env: process.env });
  const week = await getDocs(query(collection(office.db, 'trips'), where('date', '<', today), where('date', '>=', campusDate(new Date(Date.now() - 8 * 86_400_000)))));
  expect(week.size).toBeGreaterThanOrEqual(30); // 6 bus days x 3 buses x 2, Sundays off
  const one = week.docs.find((d) => d.get('direction') === 'toCampus');
  expect((await getDocs(collection(office.db, `trips/${one.id}/stopTimes`))).size).toBe(7 - (one.get('routeId') === 'cbe-gandhipuram' ? 0 : 2));
  expect((await getDocs(collection(office.db, `trips/${one.id}/boardings`))).size).toBeGreaterThan(10);
  // Stop times of trips that already ended send no alerts.
  await new Promise((r) => setTimeout(r, 3000));
  const history = await admin.db.collection('pushLog').where('data.tripId', '>=', '').get();
  expect(history.docs.filter((d) => d.get('data.tripId') !== TRIP && d.get('kind') !== 'announcement')).toHaveLength(0);
  expect((await admin.db.collection('alerts').where('kind', '==', 'delay').get()).size).toBe(0);
}, 120_000);
