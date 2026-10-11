import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-timetable',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, 'users/student1'), { name: 'Asha', role: 'student' });
    await setDoc(doc(db, 'routes/cbe-1'), { name: 'Gandhipuram – Campus', stopIds: ['a', 'campus'] });
    await setDoc(doc(db, 'timetable/t1'), { ...entry() });
  });
});

const entry = (over = {}) => ({
  routeId: 'cbe-1', mode: 'bus', name: 'Town bus 96', from: 'Gandhipuram', to: 'Ettimadai',
  departs: '07:10', direction: 'toCampus', note: null, fare: 20, ...over,
});
const office = () => env.authenticatedContext('office1', { email: 'office@cb.amrita.edu' }).firestore();
const student = () =>
  env.authenticatedContext('student1', { email: 'cb.en.u4cse21001@cb.students.amrita.edu', email_verified: true }).firestore();

describe('public bus and train timings', () => {
  test('students read them', async () => {
    await assertSucceeds(getDoc(doc(student(), 'timetable/t1')));
  });

  test('only the office writes them, and only in a usable shape', async () => {
    await assertSucceeds(setDoc(doc(office(), 'timetable/t2'), entry({ mode: 'train', departs: '17:50', direction: 'fromCampus' })));
    await assertFails(setDoc(doc(student(), 'timetable/t3'), entry()));
    await assertFails(setDoc(doc(office(), 'timetable/t4'), entry({ departs: '7:10' })));
    await assertFails(setDoc(doc(office(), 'timetable/t5'), entry({ mode: 'plane' })));
    await assertFails(setDoc(doc(office(), 'timetable/t6'), entry({ routeId: 'nowhere' })));
    await assertSucceeds(deleteDoc(doc(office(), 'timetable/t1')));
  });
});
