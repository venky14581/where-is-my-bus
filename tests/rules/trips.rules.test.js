import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-trips',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(() => env.cleanup());

const TRIP = '2026-10-10_bus-01_toCampus';

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/driver1'), { name: 'Murugan', role: 'driver', driverId: 'DRV001' });
    await setDoc(doc(db, 'users/driver2'), { name: 'Selvam', role: 'driver', driverId: 'DRV002' });
    await setDoc(doc(db, 'users/student1'), { name: 'Asha', role: 'student' });
    await setDoc(doc(db, 'routes/cbe-1'), { name: 'Gandhipuram – Campus', stopIds: ['gandhipuram', 'ukkadam', 'campus'] });
    await setDoc(doc(db, 'buses/bus-01'), { number: 'TN 37 AB 1201', routeId: 'cbe-1', driverId: 'driver1' });
    await setDoc(doc(db, 'buses/bus-02'), { number: 'TN 37 AB 1202', routeId: 'cbe-1', driverId: 'driver2' });
  });
});

const driver = (uid = 'driver1') =>
  env.authenticatedContext(uid, { email: `${uid}@drivers.whereismybus.invalid` }).firestore();
const student = () =>
  env.authenticatedContext('student1', { email: 'cb.en.u4cse21001@cb.students.amrita.edu', email_verified: true }).firestore();

const newTrip = (overrides = {}) => ({
  busId: 'bus-01',
  routeId: 'cbe-1',
  driverId: 'driver1',
  date: '2026-10-10',
  direction: 'toCampus',
  status: 'running',
  startedAt: serverTimestamp(),
  endedAt: null,
  ...overrides,
});

async function seedTrip(fields = {}) {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `trips/${TRIP}`), { ...newTrip(), startedAt: Timestamp.now(), ...fields }));
}

describe('starting a trip', () => {
  test('the assigned driver starts a trip on their bus', async () => {
    await assertSucceeds(setDoc(doc(driver(), `trips/${TRIP}`), newTrip()));
  });

  test("a driver cannot start a trip on someone else's bus", async () => {
    await assertFails(setDoc(doc(driver('driver2'), `trips/${TRIP}`), newTrip({ driverId: 'driver2' })));
    await assertFails(setDoc(doc(driver(), 'trips/2026-10-10_bus-02_toCampus'), newTrip({ busId: 'bus-02' })));
  });

  test('the trip must match its bus, route and ID', async () => {
    const db = driver();
    await assertFails(setDoc(doc(db, `trips/${TRIP}`), newTrip({ routeId: 'pkd-1' })));
    await assertFails(setDoc(doc(db, `trips/${TRIP}`), newTrip({ direction: 'sideways' })));
    await assertFails(setDoc(doc(db, 'trips/anything'), newTrip()));
    await assertFails(setDoc(doc(db, `trips/${TRIP}`), newTrip({ status: 'ended' })));
    await assertFails(setDoc(doc(db, `trips/${TRIP}`), newTrip({ passengers: 3 })));
  });

  test('students cannot start trips', async () => {
    await assertFails(setDoc(doc(student(), `trips/${TRIP}`), newTrip({ driverId: 'student1' })));
  });
});

describe('ending and resuming', () => {
  test('the driver ends the trip and can resume it', async () => {
    await seedTrip();
    await assertSucceeds(updateDoc(doc(driver(), `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(driver(), `trips/${TRIP}`), { status: 'running', endedAt: null }));
  });

  test('nobody else can end it, and other fields stay fixed', async () => {
    await seedTrip();
    await assertFails(updateDoc(doc(driver('driver2'), `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(student(), `trips/${TRIP}`), { status: 'ended', endedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(driver(), `trips/${TRIP}`), { routeId: 'other' }));
  });

  test('verified students can read trips', async () => {
    await seedTrip();
    await assertSucceeds(getDoc(doc(student(), `trips/${TRIP}`)));
  });
});

describe('stop times', () => {
  const stopTime = (stopId, overrides = {}) => ({
    stopId,
    arrivedAt: Timestamp.now(),
    recordedAt: serverTimestamp(),
    ...overrides,
  });

  test('the driver records a stop on the route while the trip runs', async () => {
    await seedTrip();
    await assertSucceeds(setDoc(doc(driver(), `trips/${TRIP}/stopTimes/ukkadam`), stopTime('ukkadam')));
  });

  test('not for a stop off the route, a mismatched ID, or an ended trip', async () => {
    await seedTrip();
    const db = driver();
    await assertFails(setDoc(doc(db, `trips/${TRIP}/stopTimes/walayar`), stopTime('walayar')));
    await assertFails(setDoc(doc(db, `trips/${TRIP}/stopTimes/ukkadam`), stopTime('campus')));
    await seedTrip({ status: 'ended' });
    await assertFails(setDoc(doc(db, `trips/${TRIP}/stopTimes/ukkadam`), stopTime('ukkadam')));
  });

  test('not by another driver or a student', async () => {
    await seedTrip();
    await assertFails(setDoc(doc(driver('driver2'), `trips/${TRIP}/stopTimes/ukkadam`), stopTime('ukkadam')));
    await assertFails(setDoc(doc(student(), `trips/${TRIP}/stopTimes/ukkadam`), stopTime('ukkadam')));
  });
});

describe('passes and boardings', () => {
  beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `trips/${TRIP}`), { ...newTrip(), startedAt: Timestamp.now() });
    await setDoc(doc(db, 'passSecrets/student1'), { secret: 'c2VjcmV0' });
    await setDoc(doc(db, `trips/${TRIP}/boardings/student1`), { type: 'pass', name: 'Asha', at: Timestamp.now() });
  }));

  test('a student reads only their own pass secret, and nobody writes one', async () => {
    await assertSucceeds(getDoc(doc(student(), 'passSecrets/student1')));
    await assertFails(getDoc(doc(driver(), 'passSecrets/student1')));
    await assertFails(setDoc(doc(student(), 'passSecrets/student1'), { secret: 'mine' }));
  });

  test("the trip's driver sees who boarded; students and other drivers do not", async () => {
    await assertSucceeds(getDoc(doc(driver(), `trips/${TRIP}/boardings/student1`)));
    await assertFails(getDoc(doc(driver('driver2'), `trips/${TRIP}/boardings/student1`)));
    await assertFails(getDoc(doc(student(), `trips/${TRIP}/boardings/student1`)));
    await assertFails(setDoc(doc(driver(), `trips/${TRIP}/boardings/student2`), { type: 'pass' }));
  });
});

describe('seat holds on another bus', () => {
  beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `trips/${TRIP}`), { ...newTrip(), startedAt: Timestamp.now(), passHolders: 40, altHeld: 1 });
    await setDoc(doc(db, 'users/student2'), { name: 'Bala', role: 'student' });
    await setDoc(doc(db, `trips/${TRIP}/holds/student1`), { uid: 'student1', name: 'Asha', stopId: 'ukkadam', status: 'held' });
  }));

  test('a student reads their own hold only, and cannot make one', async () => {
    await assertSucceeds(getDoc(doc(student(), `trips/${TRIP}/holds/student1`)));
    const other = env.authenticatedContext('student2', { email: 'cb.en.u4cse21002@cb.students.amrita.edu', email_verified: true }).firestore();
    await assertFails(getDoc(doc(other, `trips/${TRIP}/holds/student1`)));
    await assertFails(setDoc(doc(other, `trips/${TRIP}/holds/student2`), { stopId: 'ukkadam', status: 'held' }));
    await assertFails(updateDoc(doc(student(), `trips/${TRIP}/holds/student1`), { status: 'boarded' }));
  });

  test("the trip's driver lists who to expect; other drivers cannot", async () => {
    await assertSucceeds(getDocs(collection(driver(), `trips/${TRIP}/holds`)));
    await assertFails(getDocs(collection(driver('driver2'), `trips/${TRIP}/holds`)));
  });

  test('nobody changes seat counts from an app', async () => {
    await assertFails(updateDoc(doc(driver(), `trips/${TRIP}`), { altHeld: 0 }));
    await assertFails(updateDoc(doc(student(), `trips/${TRIP}`), { altHeld: 0 }));
  });
});
