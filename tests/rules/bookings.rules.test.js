import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bookings',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

const BOOKING = '2026-10-12_bus-01_fromCampus_student1';

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/student1'), { name: 'Asha', role: 'student', routeId: null, stopId: null, passValid: false });
    await setDoc(doc(db, 'users/student2'), { name: 'Bala', role: 'student', routeId: null, stopId: null, passValid: false });
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, `bookings/${BOOKING}`), { uid: 'student1', tripId: '2026-10-12_bus-01_fromCampus', status: 'confirmed', ticketToken: 't' });
  });
});

const student = (uid = 'student1') =>
  env.authenticatedContext(uid, { email: `cb.en.u4cse2100${uid.at(-1)}@cb.students.amrita.edu`, email_verified: true }).firestore();

describe('bookings', () => {
  test('a student reads their own bookings, and lists them by uid', async () => {
    await assertSucceeds(getDoc(doc(student(), `bookings/${BOOKING}`)));
    await assertSucceeds(getDocs(query(collection(student(), 'bookings'), where('uid', '==', 'student1'))));
  });

  test("nobody else's, and nobody writes them from an app", async () => {
    await assertFails(getDoc(doc(student('student2'), `bookings/${BOOKING}`)));
    await assertFails(getDocs(collection(student('student2'), 'bookings')));
    await assertFails(updateDoc(doc(student(), `bookings/${BOOKING}`), { status: 'confirmed' }));
    await assertFails(setDoc(doc(student('student2'), 'bookings/new'), { uid: 'student2', status: 'confirmed' }));
  });

  test('the office reads every booking', async () => {
    const office = env.authenticatedContext('office1', { email: 'office@amrita.edu' }).firestore();
    await assertSucceeds(getDocs(collection(office, 'bookings')));
  });
});

describe('students without a daily bus', () => {
  test('may say so, as a yes or no only', async () => {
    await assertSucceeds(updateDoc(doc(student(), 'users/student1'), { dailyRider: false }));
    await assertFails(updateDoc(doc(student(), 'users/student1'), { dailyRider: 'no' }));
  });
});
