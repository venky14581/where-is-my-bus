import { describe, expect, test } from 'vitest';

import {
  campusDate,
  countsAsSeat,
  freeAlternateSeats,
  hasPassed,
  holdsLeftBehind,
  mayRideAlternate,
  pickupStopIds,
} from './missedBus.js';

const stops = ['rs-puram', 'selvapuram', 'kovaipudur-pirivu', 'ettimadai-pirivu', 'campus'];

describe('who may ride another bus', () => {
  test('only from a route the office lets this route carry', () => {
    expect(mayRideAlternate('cbe-rs-puram', 'cbe-gandhipuram', ['cbe-gandhipuram'])).toBe(true);
    expect(mayRideAlternate('cbe-rs-puram', 'pkd-town', ['cbe-gandhipuram'])).toBe(false);
    expect(mayRideAlternate('cbe-rs-puram', 'cbe-rs-puram', ['cbe-rs-puram'])).toBe(false);
    expect(mayRideAlternate('cbe-rs-puram', null, ['cbe-gandhipuram'])).toBe(false);
    expect(mayRideAlternate('cbe-rs-puram', 'cbe-gandhipuram', undefined)).toBe(false);
  });
});

describe('seats', () => {
  test('pass holders keep their seats; the rest go to holds', () => {
    expect(freeAlternateSeats(50, 44, 0)).toBe(6);
    expect(freeAlternateSeats(50, 44, 6)).toBe(0);
    expect(freeAlternateSeats(50, 52, 0)).toBe(0);
    expect(['held', 'boarded', 'cancelled', 'missed'].filter(countsAsSeat)).toEqual(['held', 'boarded']);
  });
});

describe('pickup stops and passing', () => {
  test('a trip ends at campus in the morning and starts there in the evening', () => {
    expect(pickupStopIds(stops, 'toCampus')).toEqual(stops.slice(0, -1));
    expect(pickupStopIds(stops, 'fromCampus')).toEqual(['campus', 'ettimadai-pirivu', 'kovaipudur-pirivu', 'selvapuram']);
  });

  test('a stop is passed once it or any later stop has a stop time', () => {
    expect(hasPassed(stops, 'toCampus', 'kovaipudur-pirivu', ['rs-puram', 'selvapuram'])).toBe(false);
    expect(hasPassed(stops, 'toCampus', 'kovaipudur-pirivu', ['rs-puram', 'kovaipudur-pirivu'])).toBe(true);
    // Stops can be skipped without a record; a later one still counts.
    expect(hasPassed(stops, 'toCampus', 'selvapuram', ['ettimadai-pirivu'])).toBe(true);
    expect(hasPassed(stops, 'fromCampus', 'selvapuram', ['campus', 'ettimadai-pirivu'])).toBe(false);
    expect(hasPassed(stops, 'toCampus', 'nowhere', [])).toBe(true);
  });

  test('holds behind the bus are released, the one at the stop it just reached is not', () => {
    const holds = [
      { uid: 'a', stopId: 'rs-puram' },
      { uid: 'b', stopId: 'selvapuram' },
      { uid: 'c', stopId: 'kovaipudur-pirivu' },
    ];
    expect(holdsLeftBehind({ stopIds: stops, direction: 'toCampus', reachedStopId: 'selvapuram', holds })).toEqual(['a']);
    expect(holdsLeftBehind({ stopIds: stops, direction: 'toCampus', reachedStopId: 'campus', holds })).toEqual(['a', 'b', 'c']);
    expect(holdsLeftBehind({ stopIds: stops, direction: 'fromCampus', reachedStopId: 'selvapuram', holds })).toEqual(['c']);
  });
});

test('trips are dated on the campus clock', () => {
  // 20:00 UTC is 01:30 the next day in India.
  expect(campusDate(new Date(Date.UTC(2026, 9, 11, 20, 0)))).toBe('2026-10-12');
});
