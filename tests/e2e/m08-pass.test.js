// Module 8: pass and QR scan, through the real scanPass function. The phone
// camera is not checked here.
import { ref, serverTimestamp as rtdbNow, set } from 'firebase/database';
import { collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { passCode } from '../../functions/lib/passCode.js';
import { SEEDED, addDays, admin, campusDate, closeAll, errorCode, makeStudent, passUntil, resetAndSeed, signIn, waitFor } from './support.js';

const today = campusDate();
const TRIP = `${today}_bus-01_toCampus`;

let office;
let driver;
beforeAll(async () => {
  await resetAndSeed();
  office = await signIn(SEEDED.office);
  driver = await signIn(SEEDED.drv001);
  await setDoc(doc(driver.db, `trips/${TRIP}`), {
    busId: 'bus-01', routeId: 'cbe-gandhipuram', driverId: driver.uid, date: today,
    direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null,
  });
  // The bus is at Ukkadam.
  await set(ref(driver.rtdb, 'live/bus-01'), { lat: 10.9886, lng: 76.962, updatedAt: rtdbNow(), tripId: TRIP, status: 'running' });
}, 60_000);
afterAll(closeAll);

const secretOf = (uid) => waitFor(async () => (await admin.db.doc(`passSecrets/${uid}`).get()).get('secret'), { what: `pass secret for ${uid}` });
const scan = (code, as = driver) => as.call('scanPass', { tripId: TRIP, code });

/** A student on [routeId] given a pass by the office, as the dashboard does. */
async function withPass(uid, routeId, until = passUntil()) {
  const student = await makeStudent(uid, { routeId, stopId: routeId === 'pkd-town' ? 'walayar' : 'ukkadam' });
  await updateDoc(doc(office.db, `users/${uid}`), { passValid: true, passValidUntil: until });
  return { student, secret: await secretOf(uid) };
}

let asha;
beforeAll(async () => {
  asha = await withPass('asha', 'cbe-gandhipuram');
});

test("the office's pass gives the student a secret only they can read", async () => {
  expect((await getDoc(doc(asha.student.db, 'passSecrets/asha'))).get('secret')).toBe(asha.secret);
  const other = await signIn(SEEDED.student);
  expect(await errorCode(getDoc(doc(other.db, 'passSecrets/asha')))).toBe('permission-denied');
  expect(await errorCode(setDoc(doc(asha.student.db, 'passSecrets/asha'), { secret: 'mine' }))).toBe('permission-denied');
});

test('a valid code boards once, at the nearest stop', async () => {
  const code = passCode(asha.secret, 'asha', Date.now());
  expect(await scan(code)).toEqual({ result: 'boarded', name: 'Student asha' });
  expect(await scan(code)).toMatchObject({ result: 'alreadyBoarded' });
  const boarding = (await admin.db.doc(`trips/${TRIP}/boardings/asha`).get()).data();
  expect(boarding).toMatchObject({ type: 'pass', stopId: 'ukkadam' });
});

test('old, tampered and non-pass codes are refused with different reasons', async () => {
  const bala = await withPass('bala', 'cbe-gandhipuram');
  expect((await scan(passCode(bala.secret, 'bala', Date.now() - 120_000))).result).toBe('expiredCode');
  const good = passCode(bala.secret, 'bala', Date.now());
  const tampered = good.slice(0, -1) + (good.endsWith('A') ? 'B' : 'A');
  expect((await scan(tampered)).result).toBe('invalidCode');
  expect((await scan('https://example.com')).result).toBe('notAPass');
});

test('wrong route, expired pass and cancelled pass are refused', async () => {
  const kavi = await withPass('kavi', 'pkd-town');
  expect((await scan(passCode(kavi.secret, 'kavi', Date.now()))).result).toBe('wrongRoute');

  const old = await withPass('old', 'cbe-gandhipuram', addDays(today, -1));
  expect((await scan(passCode(old.secret, 'old', Date.now()))).result).toBe('passExpired');

  const gone = await withPass('gone', 'cbe-gandhipuram');
  await updateDoc(doc(office.db, 'users/gone'), { passValid: false });
  expect((await scan(passCode(gone.secret, 'gone', Date.now()))).result).toBe('noPass');
});

test("only this trip's driver scans and sees who boarded", async () => {
  const code = passCode(asha.secret, 'asha', Date.now());
  expect(await errorCode(scan(code, asha.student))).toBe('functions/permission-denied');
  expect(await errorCode(scan(code, await signIn(SEEDED.drv002)))).toBe('functions/permission-denied');
  expect((await getDocs(collection(driver.db, `trips/${TRIP}/boardings`))).docs.map((d) => d.id)).toEqual(['asha']);
  expect(await errorCode(getDocs(collection(asha.student.db, `trips/${TRIP}/boardings`)))).toBe('permission-denied');
});
