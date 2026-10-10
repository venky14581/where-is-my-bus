// Module 1: setup and login. See docs/modules/module-01-setup-and-login.md.
import { doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { SEEDED, admin, closeAll, errorCode, resetAndSeed, signIn, signUp } from './support.js';

beforeAll(resetAndSeed, 60_000);
afterAll(closeAll);

const newProfile = (email) => ({
  name: 'New Student', email, role: 'student', routeId: null, stopId: null, passValid: false, language: 'en',
  createdAt: serverTimestamp(),
});

describe('students', () => {
  test('a college email signs up and creates its own student profile', async () => {
    const email = 'cb.en.u4cse29999@cb.students.amrita.edu';
    const s = await signUp({ email, password: 'Bus#Pass2026' });
    await setDoc(doc(s.db, `users/${s.uid}`), newProfile(email));
    expect((await admin.db.doc(`users/${s.uid}`).get()).get('role')).toBe('student');
  });

  test('a non-college email cannot create a profile', async () => {
    const email = 'someone@gmail.com';
    const s = await signUp({ email, password: 'Bus#Pass2026' });
    expect(await errorCode(setDoc(doc(s.db, `users/${s.uid}`), newProfile(email)))).toBe('permission-denied');
  });

  test('nobody gives themselves a role or a valid pass', async () => {
    const email = 'cb.en.u4cse29998@cb.students.amrita.edu';
    const s = await signUp({ email, password: 'Bus#Pass2026' });
    expect(await errorCode(setDoc(doc(s.db, `users/${s.uid}`), { ...newProfile(email), role: 'office' }))).toBe('permission-denied');
    expect(await errorCode(setDoc(doc(s.db, `users/${s.uid}`), { ...newProfile(email), passValid: true }))).toBe('permission-denied');
    const seeded = await signIn(SEEDED.student);
    const me = doc(seeded.db, `users/${seeded.uid}`);
    expect(await errorCode(updateDoc(me, { role: 'office' }))).toBe('permission-denied');
    expect(await errorCode(updateDoc(me, { passValid: true }))).toBe('permission-denied');
    await updateDoc(me, { language: 'ta' });
  });

  test("a student reads their own profile, not someone else's", async () => {
    const s = await signIn(SEEDED.student);
    expect((await getDoc(doc(s.db, `users/${s.uid}`))).get('name')).toBe('Demo Student');
    expect(await errorCode(getDoc(doc(s.db, `users/${SEEDED.drv001.uid}`)))).toBe('permission-denied');
  });
});

describe('drivers', () => {
  test('DRV001 signs in with the PIN and saves a language; a wrong PIN fails', async () => {
    const d = await signIn(SEEDED.drv001);
    expect(d.uid).toBe(SEEDED.drv001.uid);
    await updateDoc(doc(d.db, `users/${d.uid}`), { language: 'ta' });
    expect((await admin.db.doc(`users/${d.uid}`).get()).get('language')).toBe('ta');
    expect(await errorCode(updateDoc(doc(d.db, `users/${d.uid}`), { role: 'office' }))).toBe('permission-denied');
    expect(await errorCode(signIn({ ...SEEDED.drv001, password: '000000' }))).toMatch(/auth\/(wrong-password|invalid-credential)/);
  });

  test('DRV009 has a sign-in but no profile', async () => {
    const d = await signIn(SEEDED.drv009);
    expect((await getDoc(doc(d.db, `users/${d.uid}`))).exists()).toBe(false);
  });
});

test('the office signs in with an office profile', async () => {
  const o = await signIn(SEEDED.office);
  expect((await getDoc(doc(o.db, `users/${o.uid}`))).get('role')).toBe('office');
});
