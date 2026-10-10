// Module 2: route and bus data. See docs/modules/module-02-route-and-bus-data.md.
import { collection, doc, getDocs, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { SEEDED, admin, closeAll, errorCode, resetAndSeed, signIn } from './support.js';

beforeAll(resetAndSeed, 60_000);
afterAll(closeAll);

test('the seed loads 3 routes with road paths and 3 buses with their drivers', async () => {
  const routes = await admin.db.collection('routes').get();
  expect(routes.size).toBe(3);
  for (const r of routes.docs) {
    expect(r.get('stopIds')).toEqual(r.get('stops').map((s) => s.id));
    expect(r.get('stopIds').at(-1)).toBe('campus');
    expect(r.get('path')).toBeTruthy();
  }
  const buses = Object.fromEntries((await admin.db.collection('buses').get()).docs.map((d) => [d.id, d.data()]));
  expect(Object.keys(buses).sort()).toEqual(['bus-01', 'bus-02', 'bus-03']);
  expect(buses['bus-01']).toMatchObject({ number: 'TN 37 AB 1201', routeId: 'cbe-gandhipuram', driverId: SEEDED.drv001.uid });
  expect(buses['bus-03'].driverId).toBe(SEEDED.drv002.uid);
  expect((await admin.rtdb.ref('busDrivers').get()).val()).toEqual({ 'bus-01': SEEDED.drv001.uid, 'bus-03': SEEDED.drv002.uid });
});

test('a verified student reads routes and saves a home stop on the route', async () => {
  const s = await signIn(SEEDED.student);
  expect((await getDocs(collection(s.db, 'routes'))).size).toBe(3);
  expect((await getDocs(collection(s.db, 'buses'))).size).toBe(3);
  await updateDoc(doc(s.db, `users/${s.uid}`), { routeId: 'cbe-gandhipuram', stopId: 'ukkadam' });
  expect(await errorCode(updateDoc(doc(s.db, `users/${s.uid}`), { routeId: 'cbe-gandhipuram', stopId: 'selvapuram' })))
    .toBe('permission-denied');
});

test('an unverified student cannot read routes; only the office writes them', async () => {
  const email = 'cb.en.u4cse28888@cb.students.amrita.edu';
  await admin.auth.createUser({ uid: 'unverified', email, password: 'Bus#Pass2026', emailVerified: false });
  await admin.db.doc('users/unverified').set({ name: 'U', email, role: 'student', routeId: null, stopId: null, passValid: false, language: 'en' });
  const u = await signIn({ email, password: 'Bus#Pass2026' });
  expect(await errorCode(getDocs(collection(u.db, 'routes')))).toBe('permission-denied');

  const s = await signIn(SEEDED.student);
  expect(await errorCode(updateDoc(doc(s.db, 'routes/cbe-gandhipuram'), { name: 'Mine' }))).toBe('permission-denied');
  const d = await signIn(SEEDED.drv001);
  expect(await errorCode(updateDoc(doc(d.db, 'buses/bus-01'), { capacity: 99 }))).toBe('permission-denied');
});

test('driver DRV001 sees bus TN 37 AB 1201', async () => {
  const d = await signIn(SEEDED.drv001);
  const mine = (await getDocs(collection(d.db, 'buses'))).docs.filter((b) => b.get('driverId') === d.uid);
  expect(mine.map((b) => b.get('number'))).toEqual(['TN 37 AB 1201']);
});
