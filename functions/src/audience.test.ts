import { describe, expect, test } from 'vitest';

import {
  DEFAULT_PREFS,
  approachingRiders,
  minutesLate,
  prefsOf,
  shouldAlertDelay,
  shouldPush,
  weekdayAt,
  type Rider,
} from './audience.js';
import { render } from './messages.js';

const stops = [
  { id: 'gandhipuram', scheduledTime: '07:00' },
  { id: 'town-hall', scheduledTime: '07:10' },
  { id: 'ukkadam', scheduledTime: '07:15' },
  { id: 'kuniyamuthur', scheduledTime: '07:25' },
  { id: 'madukkarai', scheduledTime: '07:40' },
  { id: 'campus', scheduledTime: '08:00' },
];

const rider = (uid: string, stopId: string, leadStops = 2): Rider => ({
  uid,
  stopId,
  prefs: { ...DEFAULT_PREFS, leadStops },
});

describe('prefsOf', () => {
  test('fills anything missing or malformed from the defaults', () => {
    expect(prefsOf(undefined)).toEqual(DEFAULT_PREFS);
    expect(prefsOf({ approaching: false, leadStops: 9, quietDays: [6, 7, 0, 'x'] })).toEqual({
      ...DEFAULT_PREFS,
      approaching: false,
      leadStops: 3,
      quietDays: [6, 7],
    });
  });
});

describe('approachingRiders', () => {
  test('tells riders within their chosen number of stops', () => {
    const riders = [rider('a', 'ukkadam'), rider('b', 'kuniyamuthur'), rider('c', 'madukkarai')];
    const due = approachingRiders({ stops, direction: 'toCampus', reachedStopId: 'town-hall', riders });
    expect(due.map((d) => [d.uid, d.stopsAway])).toEqual([
      ['a', 1],
      ['b', 2],
    ]);
  });

  test('also tells riders within 5 scheduled minutes, however many stops', () => {
    const due = approachingRiders({
      stops,
      direction: 'toCampus',
      reachedStopId: 'town-hall',
      riders: [rider('a', 'ukkadam', 1)],
    });
    expect(due).toEqual([{ uid: 'a', stopsAway: 1, minutes: 5 }]);
  });

  test('a lead of 3 stops reaches further', () => {
    const due = approachingRiders({
      stops,
      direction: 'toCampus',
      reachedStopId: 'gandhipuram',
      riders: [rider('a', 'kuniyamuthur', 3), rider('b', 'kuniyamuthur', 2)],
    });
    expect(due.map((d) => d.uid)).toEqual(['a']);
  });

  test('never tells riders whose stop is passed, reached, or on another route', () => {
    const due = approachingRiders({
      stops,
      direction: 'toCampus',
      reachedStopId: 'ukkadam',
      riders: [rider('a', 'town-hall'), rider('b', 'ukkadam'), rider('c', 'walayar')],
    });
    expect(due).toEqual([]);
  });

  test('evening trips count stops in reverse and ignore the morning timetable', () => {
    const due = approachingRiders({
      stops,
      direction: 'fromCampus',
      reachedStopId: 'madukkarai',
      riders: [rider('a', 'kuniyamuthur'), rider('b', 'ukkadam'), rider('c', 'gandhipuram')],
    });
    expect(due).toEqual([
      { uid: 'a', stopsAway: 1, minutes: null },
      { uid: 'b', stopsAway: 2, minutes: null },
    ]);
  });
});

describe('quiet days and preferences', () => {
  // 11 Oct 2026 is a Sunday; 10:00 UTC is 15:30 in India.
  const sunday = new Date('2026-10-11T10:00:00Z');

  test('weekday is read on the campus clock', () => {
    expect(weekdayAt(sunday)).toBe(7);
    // 20:00 UTC Saturday is already 01:30 Sunday in India.
    expect(weekdayAt(new Date('2026-10-10T20:00:00Z'))).toBe(7);
  });

  test('quiet days silence everything except breakdowns', () => {
    const prefs = { ...DEFAULT_PREFS, quietDays: [7] };
    expect(shouldPush(prefs, 'approaching', sunday)).toBe(false);
    expect(shouldPush(prefs, 'announcement', sunday)).toBe(false);
    expect(shouldPush(prefs, 'breakdown', sunday)).toBe(true);
  });

  test('switched-off kinds are never pushed', () => {
    const prefs = { ...DEFAULT_PREFS, delays: false };
    expect(shouldPush(prefs, 'delay', sunday)).toBe(false);
    expect(shouldPush(prefs, 'breakdown', sunday)).toBe(false);
    expect(shouldPush(prefs, 'tripStarted', sunday)).toBe(true);
  });
});

describe('delays', () => {
  test('minutes late against the timetable, on the campus clock', () => {
    // 07:52 India time at a 07:40 stop.
    expect(minutesLate({ tripDate: '2026-10-12', scheduledTime: '07:40', arrivedAt: new Date('2026-10-12T02:22:00Z') })).toBe(12);
    expect(minutesLate({ tripDate: '2026-10-12', scheduledTime: '07:40', arrivedAt: new Date('2026-10-12T02:05:00Z') })).toBe(-5);
    expect(minutesLate({ tripDate: '2026-10-12', scheduledTime: '', arrivedAt: new Date() })).toBeNull();
  });

  test('alert at 10 minutes late, then only when 10 minutes worse', () => {
    expect(shouldAlertDelay(9, 0)).toBe(false);
    expect(shouldAlertDelay(10, 0)).toBe(true);
    expect(shouldAlertDelay(14, 10)).toBe(false);
    expect(shouldAlertDelay(20, 10)).toBe(true);
  });
});

describe('messages', () => {
  test('are written in the student’s language', () => {
    const params = { busNumber: 'TN 37 AB 1201', stopName: 'Madukkarai', stopsAway: 2 };
    expect(render('approaching', 'en', params).body).toBe('TN 37 AB 1201 is 2 stops from Madukkarai.');
    expect(render('approaching', 'ta', params).title).toBe('உங்கள் பேருந்து வருகிறது');
    expect(render('approaching', 'en', { ...params, stopsAway: 1 }).body).toContain('1 stop from');
  });
});
