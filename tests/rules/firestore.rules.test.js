import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const STUDENT_EMAIL = 'cb.en.u4cse21001@cb.students.amrita.edu';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-whereismybus',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver', driverId: 'DRV001', language: null });
    await setDoc(doc(db, 'routes/cbe-1'), { name: 'Gandhipuram – Campus', city: 'Coimbatore', stopIds: ['gandhipuram', 'campus'] });
    await setDoc(doc(db, 'users/student2'), {
      name: 'Other', email: 'other@cb.students.amrita.edu', role: 'student',
      routeId: null, stopId: null, passValid: false, language: 'en',
    });
  });
});

const student = (uid = 'student1', email = STUDENT_EMAIL, verified = true) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
const driver = () =>
  env.authenticatedContext('driver1', { email: 'drv001@drivers.whereismybus.invalid' }).firestore();
const office = () =>
  env.authenticatedContext('office1', { email: 'transport.office@cb.amrita.edu', email_verified: true }).firestore();

const studentProfile = (overrides = {}) => ({
  name: 'Asha Raman',
  email: STUDENT_EMAIL,
  role: 'student',
  routeId: null,
  stopId: null,
  passValid: false,
  language: 'en',
  createdAt: serverTimestamp(),
  ...overrides,
});

describe('creating a student profile', () => {
  test('works for your own college account, even before verifying the email', async () => {
    await assertSucceeds(setDoc(doc(student('student1', STUDENT_EMAIL, false), 'users/student1'), studentProfile()));
  });

  test('is refused for a non-college email', async () => {
    const db = student('student1', 'someone@gmail.com');
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ email: 'someone@gmail.com' })));
  });

  test('is refused for a look-alike domain', async () => {
    const email = 'x@cb.students.amrita.edu.evil.com';
    await assertFails(setDoc(doc(student('student1', email), 'users/student1'), studentProfile({ email })));
  });

  test('is refused for someone else', async () => {
    await assertFails(setDoc(doc(student(), 'users/someoneElse'), studentProfile()));
  });

  test('cannot claim another role or a valid pass', async () => {
    const db = student();
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ role: 'driver' })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ role: 'office' })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ passValid: true })));
  });

  test('cannot use a different email, pre-set a route, or add fields', async () => {
    const db = student();
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ email: 'other@cb.students.amrita.edu' })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ routeId: 'r1' })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ isAdmin: true })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ language: 'fr' })));
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile({ name: '' })));
  });

  test('is refused when signed out', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'users/student1'), studentProfile()));
  });
});

describe('reading profiles', () => {
  test('you can read your own profile', async () => {
    await assertSucceeds(getDoc(doc(student('student2', 'other@cb.students.amrita.edu'), 'users/student2')));
    await assertSucceeds(getDoc(doc(driver(), 'users/driver1')));
  });

  test("students and drivers cannot read other people's profiles", async () => {
    await assertFails(getDoc(doc(student(), 'users/student2')));
    await assertFails(getDoc(doc(student(), 'users/driver1')));
    await assertFails(getDoc(doc(driver(), 'users/student2')));
  });

  test('the office can read any profile', async () => {
    await assertSucceeds(getDoc(doc(office(), 'users/student2')));
    await assertSucceeds(getDoc(doc(office(), 'users/driver1')));
  });

  test('signed-out users can read nothing', async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/student2')));
  });
});

describe('updating profiles', () => {
  const asStudent2 = () => student('student2', 'other@cb.students.amrita.edu');

  test('a student can change name, language, route and stop', async () => {
    await assertSucceeds(updateDoc(doc(asStudent2(), 'users/student2'), { name: 'New', language: 'ta' }));
    await assertSucceeds(updateDoc(doc(asStudent2(), 'users/student2'), { routeId: 'cbe-1', stopId: 'gandhipuram' }));
  });

  test('a student can only save a stop that is on an existing route', async () => {
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { routeId: 'cbe-1', stopId: 'palakkad' }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { routeId: 'no-such-route', stopId: 'gandhipuram' }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { routeId: 'cbe-1', stopId: null }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { routeId: null, stopId: 'gandhipuram' }));
  });

  test('a student cannot change role, pass or email', async () => {
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { role: 'office' }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { passValid: true }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { email: STUDENT_EMAIL }));
    await assertFails(updateDoc(doc(asStudent2(), 'users/student2'), { language: 'xx' }));
  });

  test('a driver can only change their language', async () => {
    await assertSucceeds(updateDoc(doc(driver(), 'users/driver1'), { language: 'ta' }));
    await assertFails(updateDoc(doc(driver(), 'users/driver1'), { name: 'Someone' }));
    await assertFails(updateDoc(doc(driver(), 'users/driver1'), { role: 'office' }));
    await assertFails(updateDoc(doc(driver(), 'users/driver1'), { driverId: 'DRV002' }));
  });

  test("nobody but the office can change someone else's profile", async () => {
    await assertFails(updateDoc(doc(student(), 'users/student2'), { name: 'x' }));
    await assertSucceeds(updateDoc(doc(office(), 'users/student2'), { passValid: true }));
  });
});

describe('office', () => {
  test('creates and deletes driver accounts', async () => {
    const db = office();
    await assertSucceeds(setDoc(doc(db, 'users/driver2'), { name: 'Selvam', role: 'driver', driverId: 'DRV002', language: null }));
    await assertSucceeds(deleteDoc(doc(db, 'users/driver2')));
  });

  test('students and drivers cannot delete profiles', async () => {
    await assertFails(deleteDoc(doc(student('student2', 'other@cb.students.amrita.edu'), 'users/student2')));
    await assertFails(deleteDoc(doc(driver(), 'users/driver1')));
  });
});

test('collections without rules stay closed, even to the office', async () => {
  await assertFails(getDoc(doc(student(), 'trips/t1')));
  await assertFails(setDoc(doc(office(), 'trips/t1'), { busId: 'x' }));
});
