import { describe, expect, test } from 'vitest';

import { campusClock, leaveAt, learnedSegments, secondsBetween, slotKey, trafficFactor, type LearnedTimes } from './learned.js';

// The same example as app/test/learned_times_test.dart.
const LEARNED: LearnedTimes = {
  slotMinutes: 30,
  toCampus: {
    '1': { '07:00': [600, 700, 800], '07:30': [660, 770, 880] },
    '2': { '07:00': [500, 600, 700] },
  },
};
// Monday 12 Oct 2026, 07:40 IST.
const MONDAY_0740 = new Date('2026-10-12T07:40:00+05:30');

describe('learned times', () => {
  test('campus clock and half-hour slots', () => {
    expect(campusClock(MONDAY_0740)).toEqual({ weekday: 1, minute: 460 });
    expect(campusClock(new Date('2026-10-11T23:00:00+05:30')).weekday).toBe(7);
    expect(slotKey(7 * 60 + 29)).toBe('07:00');
    expect(slotKey(7 * 60 + 30)).toBe('07:30');
    expect(slotKey(0)).toBe('00:00');
  });

  test('the nearest slot on the same weekday, within an hour', () => {
    expect(learnedSegments(LEARNED, 'toCampus', MONDAY_0740, 4)).toEqual([660, 770, 880]);
    expect(learnedSegments(LEARNED, 'toCampus', new Date('2026-10-12T06:10:00+05:30'), 4)).toEqual([600, 700, 800]);
    expect(learnedSegments(LEARNED, 'toCampus', new Date('2026-10-12T05:30:00+05:30'), 4)).toBeNull();
    expect(learnedSegments(LEARNED, 'toCampus', new Date('2026-10-14T07:00:00+05:30'), 4)).toBeNull(); // Wednesday
    expect(learnedSegments(LEARNED, 'fromCampus', MONDAY_0740, 4)).toBeNull();
    expect(learnedSegments(LEARNED, 'toCampus', MONDAY_0740, 5)).toBeNull(); // the route has changed
    expect(learnedSegments(undefined, 'toCampus', MONDAY_0740, 4)).toBeNull();
  });

  test("today's slowness only adds time, within limits, once measured", () => {
    expect(trafficFactor(undefined)).toBe(1);
    expect(trafficFactor({ ratioSum: 2.6, count: 2 })).toBe(1);
    expect(trafficFactor({ ratioSum: 3.6, count: 3 })).toBeCloseTo(1.2);
    expect(trafficFactor({ ratioSum: 2.4, count: 3 })).toBe(1);
    expect(trafficFactor({ ratioSum: 9, count: 3 })).toBe(1.5);
  });

  test('seconds between stops, learned or from the timetable', () => {
    const timetableMinutes = [420, 430, 445, 480];
    expect(secondsBetween(0, 3, { segments: [660, 770, 880], timetableMinutes })).toBe(2310);
    expect(secondsBetween(3, 1, { segments: [660, 770, 880], timetableMinutes, factor: 1.2 })).toBeCloseTo(1980);
    expect(secondsBetween(1, 3, { segments: null, timetableMinutes })).toBe(3000);
    expect(secondsBetween(0, 2, { segments: null, timetableMinutes: [420, null, 445, 480] })).toBeNull();
  });

  test('leave the walk plus two minutes before the bus', () => {
    expect(leaveAt(new Date('2026-10-12T07:40:00+05:30'), 8)).toEqual(new Date('2026-10-12T07:30:00+05:30'));
  });
});
