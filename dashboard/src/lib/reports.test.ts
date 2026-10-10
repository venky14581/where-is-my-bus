import { describe, expect, test } from 'vitest';

import {
  alongAt,
  campusTime,
  dateRange,
  guestBookings,
  minutesLateAtCampus,
  pointAlong,
  punctuality,
  ridershipByDay,
  ridershipByStop,
  routeSuggestions,
  trackingHealth,
  type ReportRoute,
  type TripRecord,
} from './reports';

const ROUTE: ReportRoute = {
  id: 'r1',
  name: 'Gandhipuram – Campus',
  stops: [
    { id: 'a', name: 'Gandhipuram', scheduledTime: '07:00', distanceFromStartM: 0 },
    { id: 'b', name: 'Ukkadam', scheduledTime: '07:15', distanceFromStartM: 3000 },
    { id: 'campus', name: 'Campus', scheduledTime: '08:00', distanceFromStartM: 15000 },
  ],
};

const at = (date: string, hhmm: string) => campusTime(date, hhmm)!;

function trip(date: string, campusAt: string | null, boardings: TripRecord['boardings'] = [], extra: Partial<TripRecord> = {}): TripRecord {
  return {
    id: `${date}_bus-01_toCampus`,
    routeId: 'r1',
    busId: 'bus-01',
    date,
    direction: 'toCampus',
    stopTimes: { a: at(date, '07:00'), ...(campusAt ? { campus: at(date, campusAt) } : {}) },
    boardings,
    ...extra,
  };
}

describe('punctuality', () => {
  test('minutes late at campus, from the campus clock', () => {
    expect(minutesLateAtCampus(trip('2026-10-12', '08:07'), ROUTE)).toBe(7);
    expect(minutesLateAtCampus(trip('2026-10-12', '07:58'), ROUTE)).toBe(-2);
    expect(minutesLateAtCampus(trip('2026-10-12', null), ROUTE)).toBeNull();
    expect(minutesLateAtCampus(trip('2026-10-12', '17:30', [], { direction: 'fromCampus' }), ROUTE)).toBeNull();
  });

  test('average, share on time and worst per route; unrecorded trips left out', () => {
    const rows = punctuality(
      [trip('2026-10-12', '08:02'), trip('2026-10-13', '08:12'), trip('2026-10-14', '07:59'), trip('2026-10-15', null)],
      [ROUTE, { id: 'r2', name: 'Empty', stops: [] }],
    );
    expect(rows[0]).toEqual({
      routeId: 'r1', routeName: 'Gandhipuram – Campus', trips: 3, averageLateMinutes: 4.3, onTimeShare: 2 / 3, worstLateMinutes: 12,
    });
    expect(rows[1]).toMatchObject({ trips: 0, averageLateMinutes: null, onTimeShare: null });
  });
});

describe('ridership', () => {
  const trips = [
    trip('2026-10-12', '08:00', [
      { type: 'pass', stopId: 'a' }, { type: 'pass', stopId: 'b' }, { type: 'alternate', stopId: 'b' },
    ]),
    trip('2026-10-12', null, [{ type: 'guest', stopId: 'campus' }], { id: 'e', direction: 'fromCampus' }),
    trip('2026-10-13', '08:00', [{ type: 'pass', stopId: 'b' }]),
  ];

  test('riders per day and route, by kind', () => {
    expect(ridershipByDay(trips)).toEqual([
      { date: '2026-10-12', routeId: 'r1', pass: 2, alternate: 1, guest: 1 },
      { date: '2026-10-13', routeId: 'r1', pass: 1, alternate: 0, guest: 0 },
    ]);
  });

  test('morning riders per stop, and per trip', () => {
    expect(ridershipByStop(trips, [ROUTE])).toEqual([
      { routeId: 'r1', stopId: 'a', stopName: 'Gandhipuram', riders: 1, perTrip: 0.5 },
      { routeId: 'r1', stopId: 'b', stopName: 'Ukkadam', riders: 3, perTrip: 1.5 },
    ]);
  });
});

test('guest riders, fares and no-shows per day and route', () => {
  const rows = guestBookings([
    { tripId: 't', routeId: 'r1', date: '2026-10-12', fare: 40, status: 'used' },
    { tripId: 't', routeId: 'r1', date: '2026-10-12', fare: 40, status: 'confirmed' },
    { tripId: 't', routeId: 'r1', date: '2026-10-12', fare: 40, status: 'cancelled' },
    { tripId: 't', routeId: 'r1', date: '2026-10-14', fare: 40, status: 'confirmed' },
  ], '2026-10-14');
  expect(rows).toEqual([
    { date: '2026-10-12', routeId: 'r1', guests: 2, fares: 80, noShows: 1 },
    { date: '2026-10-14', routeId: 'r1', guests: 1, fares: 40, noShows: 0 }, // today: still to ride
  ]);
});

describe('route suggestions', () => {
  const week = (riders: TripRecord['boardings']) =>
    ['12', '13', '14', '15', '16'].map((d) => trip(`2026-10-${d}`, '08:00', riders));

  test('quiet stops and nearly full routes, once there are enough trips', () => {
    const full = Array.from({ length: 46 }, () => ({ type: 'pass' as const, stopId: 'b' }));
    const s = routeSuggestions(week(full), [ROUTE], () => 50);
    expect(s.quietStops.map((q) => q.stopId)).toEqual(['a']);
    expect(s.fullRoutes).toEqual([{ routeId: 'r1', fullShare: 1, trips: 5 }]);
    expect(routeSuggestions(week(full).slice(0, 4), [ROUTE], () => 50)).toEqual({ quietStops: [], fullRoutes: [] });
  });
});

describe('trip replay', () => {
  const t = trip('2026-10-12', '08:00', [], {
    stopTimes: { a: at('2026-10-12', '07:00'), b: at('2026-10-12', '07:20'), campus: at('2026-10-12', '08:00') },
  });

  test('between two recorded stops, in proportion to time', () => {
    expect(alongAt(t, ROUTE, at('2026-10-12', '07:10'))).toBe(1500);
    expect(alongAt(t, ROUTE, at('2026-10-12', '07:40'))).toBe(9000);
    expect(alongAt(t, ROUTE, at('2026-10-12', '06:59'))).toBeNull();
  });

  test('a point along the path', () => {
    const path: [number, number][] = [[11, 76.96], [10.99, 76.96], [10.98, 76.96]];
    const half = pointAlong(path, 1112);
    expect(half![0]).toBeCloseTo(10.99, 3);
    expect(pointAlong(path, 99_999)).toEqual([10.98, 76.96]);
  });
});

test('date ranges end today', () => {
  expect(dateRange('2026-10-14', 7)).toEqual({ from: '2026-10-08', to: '2026-10-14' });
  expect(dateRange('2026-03-01', 2)).toEqual({ from: '2026-02-28', to: '2026-03-01' });
});

describe('tracking health', () => {
  const full = trip('2026-10-12', '08:00', [], { stopTimes: { a: 1, b: 2, campus: 3 } });
  const gap = trip('2026-10-12', null, [], { id: 'e', direction: 'fromCampus', stopTimes: { campus: 1, a: 3 } });
  const late = trip('2026-10-13', null, [], { stopTimes: { a: 1 } });

  test('stops recorded per trip, which were missed, in travel order', () => {
    const { rows } = trackingHealth([late, full, gap], [ROUTE]);
    expect(rows.map((r) => [r.tripId, r.recorded, r.expected, r.missing])).toEqual([
      ['2026-10-12_bus-01_toCampus', 3, 3, []],
      ['e', 2, 3, ['Ukkadam']],
      ['2026-10-13_bus-01_toCampus', 1, 3, ['Ukkadam', 'Campus']],
    ]);
  });

  test('per day, and the stops missed most often', () => {
    const { days, stops } = trackingHealth([full, gap, late], [ROUTE]);
    expect(days).toEqual([
      { date: '2026-10-12', trips: 2, complete: 1, recordedShare: 5 / 6 },
      { date: '2026-10-13', trips: 1, complete: 0, recordedShare: 1 / 3 },
    ]);
    expect(stops).toEqual([
      { routeId: 'r1', stopName: 'Ukkadam', missed: 2, of: 3 },
      { routeId: 'r1', stopName: 'Campus', missed: 1, of: 3 },
    ]);
  });
});
