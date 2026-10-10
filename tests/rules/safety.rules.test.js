import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-safety',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

const TRIP = '2026-10-12_bus-01_toCampus';

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver', driverId: 'DRV001' });
    await setDoc(doc(db, 'users/driver2'), { name: 'Selvam', role: 'driver', driverId: 'DRV002' });
    await setDoc(doc(db, 'users/student1'), { name: 'Asha', role: 'student' });
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, `trips/${TRIP}`), { busId: 'bus-01', routeId: 'cbe-1', driverId: 'driver1', status: 'running' });
    await setDoc(doc(db, 'trips/ended'), { busId: 'bus-01', routeId: 'cbe-1', driverId: 'driver1', status: 'ended' });
    await setDoc(doc(db, 'safetyAlerts/a1'), { type: 'sos', status: 'open', busNumber: 'TN 37', acknowledgedBy: null, acknowledgedAt: null });
    await setDoc(doc(db, 'shares/tok'), { tripId: TRIP, uid: 'student1' });
  });
});

const driver = (uid = 'driver1') => env.authenticatedContext(uid, { email: `${uid}@drivers.whereismybus.invalid` }).firestore();
const student = () =>
  env.authenticatedContext('student1', { email: 'cb.en.u4cse21001@cb.students.amrita.edu', email_verified: true }).firestore();
const office = () => env.authenticatedContext('office1', { email: 'office@amrita.edu' }).firestore();

const overspeed = (overrides = {}) => ({
  type: 'overspeed', lat: 10.99, lng: 76.96, speedKmh: 72, limitKmh: 60, createdAt: serverTimestamp(), ...overrides,
});

describe("events from the driver's phone", () => {
  test('the trip driver records overspeed and off-route on a running trip', async () => {
    await assertSucceeds(addDoc(collection(driver(), `trips/${TRIP}/events`), overspeed()));
    await assertSucceeds(addDoc(collection(driver(), `trips/${TRIP}/events`), {
      type: 'offRoute', lat: 10.99, lng: 76.96, distanceM: 420, createdAt: serverTimestamp(),
    }));
  });

  test('nobody else, not on an ended trip, and only the agreed shape', async () => {
    await assertFails(addDoc(collection(driver('driver2'), `trips/${TRIP}/events`), overspeed()));
    await assertFails(addDoc(collection(student(), `trips/${TRIP}/events`), overspeed()));
    await assertFails(addDoc(collection(driver(), 'trips/ended/events'), overspeed()));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/events`), overspeed({ type: 'sos' })));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/events`), overspeed({ note: 'hi' })));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/events`), overspeed({ lat: 200 })));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/events`), overspeed({ createdAt: new Date(0) })));
  });
});

describe('safety alerts', () => {
  test('only the office reads them, and only marks them acknowledged', async () => {
    await assertSucceeds(getDocs(collection(office(), 'safetyAlerts')));
    await assertFails(getDoc(doc(driver(), 'safetyAlerts/a1')));
    await assertFails(getDoc(doc(student(), 'safetyAlerts/a1')));
    await assertSucceeds(updateDoc(doc(office(), 'safetyAlerts/a1'), {
      status: 'acknowledged', acknowledgedBy: 'office1', acknowledgedAt: serverTimestamp(),
    }));
  });

  test('nobody writes or rewrites one from an app', async () => {
    await assertFails(setDoc(doc(student(), 'safetyAlerts/fake'), { type: 'sos', status: 'open' }));
    await assertFails(updateDoc(doc(office(), 'safetyAlerts/a1'), { busNumber: 'X' }));
    await assertFails(updateDoc(doc(office(), 'safetyAlerts/a1'), {
      status: 'acknowledged', acknowledgedBy: 'someone-else', acknowledgedAt: serverTimestamp(),
    }));
  });
});

test("parents' trip links are reachable only through the function", async () => {
  await assertFails(getDoc(doc(student(), 'shares/tok')));
  await assertFails(getDoc(doc(office(), 'shares/tok')));
  await assertFails(setDoc(doc(student(), 'shares/mine'), { tripId: TRIP }));
  const anyone = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anyone, 'shares/tok')));
});
