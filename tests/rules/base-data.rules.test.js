import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-base-data', // separate from firestore.rules.test.js so clears don't collide
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/office1'), { name: 'Office', role: 'office' });
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver', driverId: 'DRV001', language: 'ta' });
    for (const uid of ['verified', 'unverified']) {
      await setDoc(doc(db, `users/${uid}`), { name: uid, role: 'student', passValid: false, routeId: null, stopId: null });
    }
    await setDoc(doc(db, 'routes/cbe-1'), { name: 'Gandhipuram – Campus', city: 'Coimbatore', stopIds: ['gandhipuram', 'campus'] });
    await setDoc(doc(db, 'buses/bus-01'), { number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-1', driverId: 'driver1' });
    await setDoc(doc(db, 'routeAccess/cbe-1'), { acceptsFrom: [] });
  });
});

const studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';
const verified = () => env.authenticatedContext('verified', { email: studentEmail, email_verified: true }).firestore();
const unverified = () => env.authenticatedContext('unverified', { email: studentEmail, email_verified: false }).firestore();
const driver = () => env.authenticatedContext('driver1', { email: 'drv001@drivers.whereismybus.invalid' }).firestore();
const office = () => env.authenticatedContext('office1', { email: 'transport.office@cb.amrita.edu' }).firestore();
const outsider = () => env.authenticatedContext('outsider', { email: 'someone@gmail.com', email_verified: true }).firestore();

const paths = ['routes/cbe-1', 'buses/bus-01', 'routeAccess/cbe-1'];

describe('reading routes, buses and route access', () => {
  test('verified students, drivers and the office can read', async () => {
    for (const db of [verified(), driver(), office()]) {
      for (const path of paths) await assertSucceeds(getDoc(doc(db, path)));
    }
  });

  test('a driver can find their own bus', async () => {
    await assertSucceeds(getDocs(query(collection(driver(), 'buses'), where('driverId', '==', 'driver1'))));
  });

  test('unverified students, outsiders and signed-out users cannot', async () => {
    const dbs = [unverified(), outsider(), env.unauthenticatedContext().firestore()];
    for (const db of dbs) {
      for (const path of paths) await assertFails(getDoc(doc(db, path)));
    }
  });
});

describe('writing base data', () => {
  const route = (overrides = {}) => ({
    name: 'New', city: 'Coimbatore', active: true,
    stops: [{ id: 'a' }, { id: 'campus' }], stopIds: ['a', 'campus'], ...overrides,
  });

  test('only the office can add or change routes, buses and access', async () => {
    await assertSucceeds(setDoc(doc(office(), 'routes/cbe-2'), route({ guestFare: 40 })));
    await assertSucceeds(updateDoc(doc(office(), 'buses/bus-01'), { driverId: null }));
    await assertSucceeds(updateDoc(doc(office(), 'routeAccess/cbe-1'), { acceptsFrom: ['cbe-2'] }));
  });

  test('office edits must leave routes and buses usable', async () => {
    const db = office();
    await assertFails(setDoc(doc(db, 'routes/cbe-2'), route({ stopIds: ['a'] })));
    await assertFails(setDoc(doc(db, 'routes/cbe-2'), route({ stops: [{ id: 'a' }], stopIds: ['a'] })));
    await assertFails(setDoc(doc(db, 'routes/cbe-2'), route({ name: '' })));
    await assertFails(setDoc(doc(db, 'routes/cbe-2'), route({ guestFare: -5 })));
    await assertFails(updateDoc(doc(db, 'buses/bus-01'), { capacity: 0 }));
    await assertFails(updateDoc(doc(db, 'buses/bus-01'), { routeId: 'no-such-route' }));
    await assertSucceeds(updateDoc(doc(db, 'buses/bus-01'), { capacity: 55, routeId: null }));
  });

  test('booking settings: everyone with access reads, only the office writes', async () => {
    await assertSucceeds(setDoc(doc(office(), 'settings/booking'), { opensAt: '18:00', closesMinutesBefore: 30 }));
    await assertSucceeds(getDoc(doc(verified(), 'settings/booking')));
    await assertFails(setDoc(doc(verified(), 'settings/booking'), { opensAt: '00:00' }));
  });

  test('students and drivers cannot', async () => {
    for (const db of [verified(), driver()]) {
      await assertFails(setDoc(doc(db, 'routes/cbe-2'), { name: 'New' }));
      await assertFails(updateDoc(doc(db, 'buses/bus-01'), { driverId: 'driver1', capacity: 99 }));
      await assertFails(updateDoc(doc(db, 'routeAccess/cbe-1'), { acceptsFrom: ['anything'] }));
    }
  });
});
