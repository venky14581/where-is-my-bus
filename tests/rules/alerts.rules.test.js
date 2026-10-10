import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, addDoc, collection, deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-alerts',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

const TRIP = '2026-10-12_bus-01_toCampus';
const EMAIL = 'cb.en.u4cse21001@cb.students.amrita.edu';

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver' });
    await setDoc(doc(db, 'users/driver2'), { name: 'Selvam', role: 'driver' });
    await setDoc(doc(db, 'users/student1'), {
      name: 'Asha', email: EMAIL, role: 'student', routeId: 'cbe-1', stopId: 'ukkadam', passValid: false, language: 'en',
    });
    await setDoc(doc(db, 'routes/cbe-1'), { name: 'R', stopIds: ['gandhipuram', 'ukkadam', 'campus'] });
    await setDoc(doc(db, `trips/${TRIP}`), {
      busId: 'bus-01', routeId: 'cbe-1', driverId: 'driver1', date: '2026-10-12', direction: 'toCampus',
      status: 'running', startedAt: Timestamp.now(), endedAt: null,
    });
    await setDoc(doc(db, 'alerts/a1'), { routeId: 'cbe-1', kind: 'tripStarted', params: {}, createdAt: Timestamp.now() });
  });
});

const student = () => env.authenticatedContext('student1', { email: EMAIL, email_verified: true }).firestore();
const driver = (uid = 'driver1') => env.authenticatedContext(uid, { email: `${uid}@drivers.whereismybus.invalid` }).firestore();
const office = () => env.authenticatedContext('office1', { email: 'transport.office@cb.amrita.edu' }).firestore();

describe('alert settings', () => {
  test('a student can save valid settings', async () => {
    await assertSucceeds(updateDoc(doc(student(), 'users/student1'), {
      alerts: { approaching: true, tripStarted: false, delays: true, announcements: true, leadStops: 3, quietDays: [6, 7] },
    }));
  });

  test('bad values and extra keys are refused', async () => {
    const db = student();
    await assertFails(updateDoc(doc(db, 'users/student1'), { alerts: { leadStops: 9 } }));
    await assertFails(updateDoc(doc(db, 'users/student1'), { alerts: { approaching: 'yes' } }));
    await assertFails(updateDoc(doc(db, 'users/student1'), { alerts: { spam: true } }));
  });
});

describe('devices', () => {
  const token = 'fcm-token-abc:123';

  test('a user registers and removes their own device', async () => {
    const ref = doc(student(), `users/student1/devices/${token}`);
    await assertSucceeds(setDoc(ref, { platform: 'android', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test("nobody touches someone else's devices", async () => {
    await assertFails(setDoc(doc(driver(), `users/student1/devices/${token}`), { platform: 'android', updatedAt: serverTimestamp() }));
    await assertFails(getDoc(doc(driver(), `users/student1/devices/${token}`)));
  });
});

describe('driver reports', () => {
  const report = (type) => ({ type, createdAt: serverTimestamp() });

  test('the trip driver reports running late or a breakdown', async () => {
    await assertSucceeds(addDoc(collection(driver(), `trips/${TRIP}/reports`), report('late')));
    await assertSucceeds(addDoc(collection(driver(), `trips/${TRIP}/reports`), report('breakdown')));
  });

  test('not another driver, not a student, not other types, not after the trip ends', async () => {
    await assertFails(addDoc(collection(driver('driver2'), `trips/${TRIP}/reports`), report('late')));
    await assertFails(addDoc(collection(student(), `trips/${TRIP}/reports`), report('late')));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/reports`), report('party')));
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), `trips/${TRIP}`), { status: 'ended' }));
    await assertFails(addDoc(collection(driver(), `trips/${TRIP}/reports`), report('late')));
  });
});

describe('alerts and announcements', () => {
  test('students read alerts; nobody writes them', async () => {
    await assertSucceeds(getDoc(doc(student(), 'alerts/a1')));
    await assertFails(setDoc(doc(student(), 'alerts/a2'), { kind: 'breakdown' }));
    await assertFails(setDoc(doc(office(), 'alerts/a2'), { kind: 'breakdown' }));
  });

  const announcement = (overrides = {}) => ({
    routeId: 'cbe-1', title: 'Holiday', body: 'No buses on Monday.', createdAt: serverTimestamp(), createdBy: 'office1', ...overrides,
  });

  test('the office announces to a route or to everyone', async () => {
    await assertSucceeds(addDoc(collection(office(), 'announcements'), announcement()));
    await assertSucceeds(addDoc(collection(office(), 'announcements'), announcement({ routeId: null })));
  });

  test('not to a route that does not exist, not empty, not by students', async () => {
    await assertFails(addDoc(collection(office(), 'announcements'), announcement({ routeId: 'nope' })));
    await assertFails(addDoc(collection(office(), 'announcements'), announcement({ title: '' })));
    await assertFails(addDoc(collection(student(), 'announcements'), announcement({ createdBy: 'student1' })));
  });

  test('server-only records stay closed', async () => {
    await assertFails(getDoc(doc(office(), 'pushLog/x')));
    await assertFails(setDoc(doc(student(), `trips/${TRIP}/approachingSent/student1`), { at: 1 }));
  });
});
