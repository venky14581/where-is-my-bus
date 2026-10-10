import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { get, ref, serverTimestamp, set, update } from 'firebase/database';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-whereismybus',
    database: { rules: readFileSync('database.rules.json', 'utf8') },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.database();
    await set(ref(db, 'busDrivers'), { 'bus-01': 'driver1', 'bus-02': 'driver2' });
    await set(ref(db, 'officeUids/office1'), true);
  });
});

const driver = (uid = 'driver1') =>
  env.authenticatedContext(uid, { email: `${uid}@drivers.whereismybus.invalid` }).database();
const student = (verified = true, email = 'cb.en.u4cse21001@cb.students.amrita.edu') =>
  env.authenticatedContext('student1', { email, email_verified: verified }).database();
const office = () => env.authenticatedContext('office1', { email: 'transport.office@cb.amrita.edu' }).database();

const point = (overrides = {}) => ({
  lat: 10.98,
  lng: 76.96,
  speed: 11,
  heading: 180,
  accuracy: 8,
  updatedAt: serverTimestamp(),
  tripId: '2026-10-10_bus-01_toCampus',
  status: 'running',
  ...overrides,
});

describe('writing the live position', () => {
  test("only the bus's assigned driver can write it", async () => {
    await assertSucceeds(set(ref(driver(), 'live/bus-01'), point()));
    await assertFails(set(ref(driver('driver2'), 'live/bus-01'), point()));
    await assertFails(set(ref(student(), 'live/bus-01'), point()));
    await assertFails(set(ref(env.unauthenticatedContext().database(), 'live/bus-01'), point()));
  });

  test('the driver can mark the bus offline or ended', async () => {
    await assertSucceeds(set(ref(driver(), 'live/bus-01'), point()));
    await assertSucceeds(update(ref(driver(), 'live/bus-01'), { status: 'offline' }));
    await assertSucceeds(update(ref(driver(), 'live/bus-01'), { status: 'ended', updatedAt: serverTimestamp() }));
  });

  test('bad or extra values are refused', async () => {
    const db = driver();
    await assertFails(set(ref(db, 'live/bus-01'), point({ lat: 123 })));
    await assertFails(set(ref(db, 'live/bus-01'), point({ speed: 200 })));
    await assertFails(set(ref(db, 'live/bus-01'), point({ status: 'parked' })));
    await assertFails(set(ref(db, 'live/bus-01'), point({ updatedAt: Date.now() + 3_600_000 })));
    await assertFails(set(ref(db, 'live/bus-01'), point({ history: [1, 2, 3] })));
    const { lat, ...withoutLat } = point();
    await assertFails(set(ref(db, 'live/bus-01'), withoutLat));
  });

  test('nobody but the office can change who drives a bus', async () => {
    await assertFails(set(ref(driver('driver2'), 'busDrivers/bus-01'), 'driver2'));
    await assertSucceeds(set(ref(office(), 'busDrivers/bus-01'), 'driver2'));
  });
});

describe('reading the live position', () => {
  beforeEach(() => env.withSecurityRulesDisabled((ctx) => set(ref(ctx.database(), 'live/bus-01'), point({ updatedAt: Date.now() }))));

  test('verified students, drivers and the office can read all buses', async () => {
    await assertSucceeds(get(ref(student(), 'live')));
    await assertSucceeds(get(ref(driver('driver2'), 'live')));
    await assertSucceeds(get(ref(office(), 'live')));
  });

  test('unverified students, outsiders and signed-out users cannot', async () => {
    await assertFails(get(ref(student(false), 'live')));
    await assertFails(get(ref(student(true, 'someone@gmail.com'), 'live')));
    await assertFails(get(ref(env.unauthenticatedContext().database(), 'live')));
  });
});
