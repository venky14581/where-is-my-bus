import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, test } from 'vitest';
import { assertFails, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { get, ref, set } from 'firebase/database';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-whereismybus',
    database: { rules: readFileSync('database.rules.json', 'utf8') },
  });
});

afterAll(() => env.cleanup());

// Module 3 opens live/{busId} to the assigned driver.
test('the Realtime Database is closed until Module 3', async () => {
  const db = env.authenticatedContext('driver1', { email: 'drv001@drivers.whereismybus.invalid' }).database();
  await assertFails(set(ref(db, 'live/bus1'), { lat: 10.9, lng: 76.9 }));
  await assertFails(get(ref(db, 'live/bus1')));
});
