// Module 11: smart features. The learned times come from ml/out (synthetic
// trips until real ones are recorded), loaded by the seed.
import { Timestamp, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';

import { SEEDED, addDays, admin, campusDate, closeAll, errorCode, makeStudent, passUntil, resetAndSeed, signIn, sleep, waitFor } from './support.js';
import { scheduleEveningTrips } from '../../functions/lib/bookings.js';
import { learnedSegments, secondsBetween } from '../../functions/lib/learned.js';

beforeAll(resetAndSeed, 60_000);
afterAll(closeAll);

const minutesOf = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3));

test('the seed loads learned times for every route, readable by college accounts only', async () => {
  const learned = (await admin.db.doc('segmentTimes/cbe-gandhipuram').get()).data();
  expect(learned.source).toBe('synthetic');
  expect(learned.slotMinutes).toBe(30);
  const anyDay = Object.values(learned.toCampus)[0];
  expect(Object.values(anyDay)[0]).toHaveLength(6); // 7 stops, 6 stretches
  expect(learned.evaluation.maeSeconds.model).toBeLessThan(learned.evaluation.maeSeconds.timetable);
  expect(Object.keys(learned.delayByWeekday).length).toBeGreaterThan(0);
  const student = await signIn(SEEDED.student);
  expect((await getDoc(doc(student.db, 'segmentTimes/pkd-town'))).exists()).toBe(true);
  expect(await errorCode(setDoc(doc(student.db, 'segmentTimes/pkd-town'), { slotMinutes: 1 }))).toBe('permission-denied');
});

describe('a morning trip', () => {
  const today = campusDate();
  const TRIP = `${today}_bus-01_toCampus`;
  const pushes = async (uid) => (await admin.db.collection('pushLog').where('kind', '==', 'leaveHome').where('uid', '==', uid).get()).size;
  let driver;
  let stops;
  let learned;

  beforeAll(async () => {
    const route = (await admin.db.doc('routes/cbe-gandhipuram').get()).data();
    stops = route.stops;
    learned = (await admin.db.doc('segmentTimes/cbe-gandhipuram').get()).data();
    // Near: one stretch out with a long walk. Far: four stretches out with a short one.
    await makeStudent('near', { routeId: 'cbe-gandhipuram', stopId: 'town-hall', walkMinutes: 15 });
    await makeStudent('far', { routeId: 'cbe-gandhipuram', stopId: 'madukkarai', walkMinutes: 10 });
    await makeStudent('quiet', { routeId: 'cbe-gandhipuram', stopId: 'town-hall', walkMinutes: 15, alerts: { leaveHome: false } });
    await makeStudent('nowalk', { routeId: 'cbe-gandhipuram', stopId: 'town-hall' });
    driver = await signIn(SEEDED.drv001);
    await setDoc(doc(driver.db, `trips/${TRIP}`), {
      busId: 'bus-01', routeId: 'cbe-gandhipuram', driverId: driver.uid, date: today,
      direction: 'toCampus', status: 'running', startedAt: serverTimestamp(), endedAt: null,
    });
  }, 60_000);

  test('at the start, only a rider who must leave now is told', async () => {
    await waitFor(async () => (await pushes('near')) === 1, { what: 'leave-home push to near' });
    await sleep(1500);
    expect(await pushes('far')).toBe(0);
    expect(await pushes('quiet')).toBe(0);
    expect(await pushes('nowalk')).toBe(0);
    const push = (await admin.db.collection('pushLog').where('kind', '==', 'leaveHome').where('uid', '==', 'near').get()).docs[0].data();
    expect(push.title).toBe('Time to leave');
    expect(push.body).toMatch(/^Leave now for Town Hall: TN 37 AB 1201 should be there around \d\d:\d\d\.$/);
  });

  test('stretches driven 1.5 times slower than expected slow down the day', async () => {
    // Stop times in the recent past, each stretch 1.5x what the server expects.
    const timetableMinutes = stops.map((s) => minutesOf(s.scheduledTime));
    let at = new Date(Date.now() - 60 * 60_000);
    const reach = (i, when) => setDoc(doc(driver.db, `trips/${TRIP}/stopTimes/${stops[i].id}`), {
      stopId: stops[i].id, arrivedAt: Timestamp.fromDate(when), recordedAt: serverTimestamp(),
    });
    await reach(0, at);
    for (let i = 1; i <= 3; i++) {
      const expected = secondsBetween(i - 1, i, { segments: learnedSegments(learned, 'toCampus', at, stops.length), timetableMinutes });
      at = new Date(at.getTime() + expected * 1500);
      await reach(i, at);
    }
    const conditions = await waitFor(async () => {
      const c = (await admin.db.doc(`conditions/${campusDate(at)}`).get()).data();
      return c?.count === 3 && c;
    }, { what: 'conditions for 3 stretches' });
    expect(conditions.ratioSum / conditions.count).toBeCloseTo(1.5, 2);
  });

  test('a rider is told once the stop before theirs is reached, and only once', async () => {
    // Kuniyamuthur (stop 3) was reached above; Madukkarai is next.
    await waitFor(async () => (await pushes('far')) === 1, { what: 'leave-home push to far' });
    await sleep(1500);
    expect(await pushes('near')).toBe(1);
  });
});

describe('not riding today', () => {
  const tomorrow = addDays(campusDate(), 1);
  const T1 = `${tomorrow}_bus-01_fromCampus`;
  const trip = () => admin.db.doc(`trips/${T1}`);
  let pass;
  let guest;

  beforeAll(async () => {
    await admin.db.doc('routes/cbe-gandhipuram').update({ guestFare: 40 });
    pass = await makeStudent('pavi', { routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: true, passValidUntil: passUntil() });
    guest = await makeStudent('gita');
    await scheduleEveningTrips(new Date());
    await trip().update({ bookingOpensAt: new Date(Date.now() - 3600_000), bookingClosesAt: new Date(Date.now() + 3600_000) });
  }, 60_000);

  const setNotRiding = (who, notRiding) => who.call('setNotRiding', { tripId: T1, notRiding }).then((r) => r.result);

  test('a pass holder frees their seat, once however often they ask', async () => {
    expect((await trip().get()).get('notRiding')).toBe(0);
    expect(await setNotRiding(pass, true)).toBe('notRiding');
    expect(await setNotRiding(pass, true)).toBe('notRiding');
    expect((await trip().get()).get('notRiding')).toBe(1);
    expect((await getDoc(doc(pass.db, `trips/${T1}/notRiding/pavi`))).exists()).toBe(true);
    expect(await errorCode(getDoc(doc(guest.db, `trips/${T1}/notRiding/pavi`)))).toBe('permission-denied');
  });

  test('the freed seat can be sold, and then cannot be taken back', async () => {
    // A full bus apart from the seat Pavi gave up.
    await trip().update({ passHolders: 50 });
    const booked = await guest.call('bookSeat', { tripId: T1, stopId: 'ukkadam' });
    expect(booked.result).toBe('booked');
    expect(await setNotRiding(pass, false)).toBe('seatTaken');
    expect((await trip().get()).get('notRiding')).toBe(1);
    // The guest gives it up; Pavi can ride again.
    expect((await guest.call('cancelBooking', { bookingId: booked.bookingId })).result).toBe('cancelled');
    expect(await setNotRiding(pass, false)).toBe('riding');
    expect((await trip().get()).get('notRiding')).toBe(0);
  });

  test('only for your own route with a pass, and fixed once booking closes', async () => {
    const other = await makeStudent('ravi', { routeId: 'cbe-rs-puram', stopId: 'selvapuram', passValid: true, passValidUntil: passUntil() });
    expect(await setNotRiding(other, true)).toBe('notYourBus');
    const noPass = await makeStudent('nina', { routeId: 'cbe-gandhipuram', stopId: 'ukkadam' });
    expect(await setNotRiding(noPass, true)).toBe('noPass');
    await trip().update({ bookingClosesAt: new Date(Date.now() - 60_000) });
    expect(await setNotRiding(pass, true)).toBe('locked');
    expect(await errorCode(guest.call('setNotRiding', { tripId: `${tomorrow}_bus-01_toCampus`, notRiding: true }))).toBe('functions/not-found');
  });
});

test('a student saves their walk to the stop', async () => {
  const s = await signIn(SEEDED.student);
  await updateDoc(doc(s.db, `users/${s.uid}`), { walkMinutes: 12, alerts: { leaveHome: true } });
  expect((await admin.db.doc(`users/${s.uid}`).get()).get('walkMinutes')).toBe(12);
  expect(await errorCode(updateDoc(doc(s.db, `users/${s.uid}`), { walkMinutes: 600 }))).toBe('permission-denied');
});
