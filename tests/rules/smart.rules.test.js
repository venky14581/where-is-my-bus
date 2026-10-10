import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-smart',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

const TRIP = '2026-10-12_bus-01_fromCampus';

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/student1'), { name: 'Asha', role: 'student', routeId: null, stopId: null, passValid: false });
    await setDoc(doc(db, 'users/student2'), { name: 'Bala', role: 'student', routeId: null, stopId: null, passValid: false });
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver', driverId: 'DRV001' });
    await setDoc(doc(db, 'segmentTimes/cbe-1'), { slotMinutes: 30, toCampus: {}, delayByWeekday: {} });
    await setDoc(doc(db, 'conditions/2026-10-12'), { ratioSum: 3.6, count: 3 });
    await setDoc(doc(db, `trips/${TRIP}/notRiding/student1`), { at: new Date() });
  });
});

const student = (uid = 'student1', verified = true) =>
  env.authenticatedContext(uid, { email: `cb.en.u4cse2100${uid.at(-1)}@cb.students.amrita.edu`, email_verified: verified }).firestore();
const driver = () => env.authenticatedContext('driver1', { email: 'drv001@drivers.whereismybus.invalid' }).firestore();

describe('learned times and conditions', () => {
  test('college accounts read them; nobody writes them from an app', async () => {
    await assertSucceeds(getDoc(doc(student(), 'segmentTimes/cbe-1')));
    await assertSucceeds(getDoc(doc(driver(), 'conditions/2026-10-12')));
    await assertFails(getDoc(doc(student('student1', false), 'segmentTimes/cbe-1')));
    await assertFails(setDoc(doc(student(), 'segmentTimes/cbe-1'), { slotMinutes: 30 }));
    await assertFails(updateDoc(doc(student(), 'conditions/2026-10-12'), { count: 0 }));
  });
});

describe('not riding today', () => {
  test('a student reads only their own mark and cannot write one', async () => {
    await assertSucceeds(getDoc(doc(student(), `trips/${TRIP}/notRiding/student1`)));
    await assertFails(getDoc(doc(student('student2'), `trips/${TRIP}/notRiding/student1`)));
    await assertFails(setDoc(doc(student('student2'), `trips/${TRIP}/notRiding/student2`), { at: new Date() }));
  });
});

describe('walk to the stop and the leave-home alert', () => {
  test('whole minutes from 1 to 60, or none; the alert is a yes or no', async () => {
    const me = doc(student(), 'users/student1');
    await assertSucceeds(updateDoc(me, { walkMinutes: 8 }));
    await assertSucceeds(updateDoc(me, { walkMinutes: null }));
    await assertFails(updateDoc(me, { walkMinutes: 0 }));
    await assertFails(updateDoc(me, { walkMinutes: 90 }));
    await assertFails(updateDoc(me, { walkMinutes: 7.5 }));
    await assertSucceeds(updateDoc(me, { alerts: { leaveHome: false } }));
    await assertFails(updateDoc(me, { alerts: { leaveHome: 'no' } }));
  });

  test('nobody sets them for someone else', async () => {
    await assertFails(updateDoc(doc(student('student2'), 'users/student1'), { walkMinutes: 5 }));
  });
});
