// Module 9: missed-bus help. A Gandhipuram student holds a seat on the
// R.S. Puram bus (routeAccess lets it carry Gandhipuram riders).
import { Timestamp, collection, doc, getDoc, getDocs, serverTimestamp, setDoc } from 'firebase/firestore';
import { afterAll, beforeAll, expect, test } from 'vitest';

import { passCode } from '../../functions/lib/passCode.js';
import { SEEDED, admin, campusDate, campusTime, closeAll, errorCode, makeStudent, passUntil, resetAndSeed, signIn, sleep, waitFor } from './support.js';

const today = campusDate();
const TRIP = `${today}_bus-02_toCampus`;
const tripDoc = () => admin.db.doc(`trips/${TRIP}`);
const altHeld = async () => (await tripDoc().get()).get('altHeld');

let driver;
const s = {};
const withPass = (uid, routeId) => makeStudent(uid, {
  routeId, stopId: routeId === 'pkd-town' ? 'walayar' : routeId === 'cbe-rs-puram' ? 'selvapuram' : 'ukkadam',
  passValid: true, passValidUntil: passUntil(),
});

beforeAll(async () => {
  await resetAndSeed();
  await admin.db.doc('buses/bus-02').update({ driverId: SEEDED.drv002.uid });
  s.sana = await withPass('sana', 'cbe-gandhipuram');
  s.tara = await withPass('tara', 'cbe-gandhipuram');
  s.uma = await withPass('uma', 'cbe-gandhipuram');
  s.vani = await withPass('vani', 'cbe-gandhipuram');
  s.kavi = await withPass('kavi', 'pkd-town');
  s.riya = await withPass('riya', 'cbe-rs-puram'); // the bus's own pass holder
  s.nopass = await makeStudent('nopass', { routeId: 'cbe-gandhipuram', stopId: 'ukkadam' });
  driver = await signIn(SEEDED.drv002);
  await setDoc(doc(driver.db, `trips/${TRIP}`), {
    busId: 'bus-02', routeId: 'cbe-rs-puram', driverId: driver.uid, date: today,
    direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null,
  });
  await waitFor(async () => (await tripDoc().get()).get('passHolders') === 1, { what: 'passHolders counted' });
}, 90_000);
afterAll(closeAll);

const hold = (who, stopId) => s[who].call('holdSeat', { tripId: TRIP, stopId }).then((r) => r.result);
const scan = async (uid) => {
  const secret = (await admin.db.doc(`passSecrets/${uid}`).get()).get('secret');
  return (await driver.call('scanPass', { tripId: TRIP, code: passCode(secret, uid, Date.now()) })).result;
};
const reach = (stopId, hhmm) => setDoc(doc(driver.db, `trips/${TRIP}/stopTimes/${stopId}`), {
  stopId, arrivedAt: Timestamp.fromDate(campusTime(today, hhmm)), recordedAt: serverTimestamp(),
});

test('holding a seat counts it once', async () => {
  expect(await hold('sana', 'selvapuram')).toBe('held');
  expect(await hold('sana', 'selvapuram')).toBe('held');
  expect(await altHeld()).toBe(1);
});

test('refused: route not allowed, not a pickup stop, no pass', async () => {
  expect(await hold('kavi', 'selvapuram')).toBe('notAllowed');
  expect(await hold('tara', 'campus')).toBe('badStop');
  expect(await hold('nopass', 'selvapuram')).toBe('noPass');
  expect(await altHeld()).toBe(1);
});

test('the driver sees who to expect; a student reads only their own hold', async () => {
  expect((await getDocs(collection(driver.db, `trips/${TRIP}/holds`))).docs.map((d) => d.get('stopId'))).toEqual(['selvapuram']);
  expect((await getDoc(doc(s.sana.db, `trips/${TRIP}/holds/sana`))).get('status')).toBe('held');
  expect(await errorCode(getDoc(doc(s.tara.db, `trips/${TRIP}/holds/sana`)))).toBe('permission-denied');
});

test('giving up frees the seat; without a held seat the pass is refused, with one it boards as alternate', async () => {
  expect((await s.sana.call('cancelHold', { tripId: TRIP })).result).toBe('cancelled');
  expect(await altHeld()).toBe(0);
  expect(await scan('sana')).toBe('noSeatHeld');
  expect(await hold('sana', 'selvapuram')).toBe('held');
  expect(await scan('sana')).toBe('boarded');
  expect((await admin.db.doc(`trips/${TRIP}/boardings/sana`).get()).get('type')).toBe('alternate');
  expect((await admin.db.doc(`trips/${TRIP}/holds/sana`).get()).get('status')).toBe('boarded');
  expect(await altHeld()).toBe(1); // a used seat stays counted
  expect(await scan('riya')).toBe('boarded'); // the route's own pass holder needs no hold
});

test('two students race for the last seat: one gets it', async () => {
  await tripDoc().update({ passHolders: 48 }); // 50 seats - 48 - 1 used = 1 left
  const results = await Promise.all([hold('tara', 'kovaipudur-pirivu'), hold('uma', 'kovaipudur-pirivu')]);
  expect(results.sort()).toEqual(['full', 'held']);
  expect(await altHeld()).toBe(2);
});

test('the seat goes back once the bus leaves the stop behind, not at the stop', async () => {
  const winner = (await admin.db.doc(`trips/${TRIP}/holds/tara`).get()).exists ? 'tara' : 'uma';
  await reach('kovaipudur-pirivu', '07:30');
  await sleep(3000);
  expect((await admin.db.doc(`trips/${TRIP}/holds/${winner}`).get()).get('status')).toBe('held');
  await reach('ettimadai-pirivu', '07:48');
  await waitFor(async () => (await admin.db.doc(`trips/${TRIP}/holds/${winner}`).get()).get('status') === 'missed', { what: 'hold released' });
  expect(await altHeld()).toBe(1);
  expect(await hold('vani', 'selvapuram')).toBe('passed');
});
