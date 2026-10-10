import { describe, expect, test } from 'vitest';

import { describeAge, liveState, parseLive } from './live';
import { decodePolyline } from './polyline';
import { passState } from './passes';
import { buildPath, routeDocument, routeProblems, slugify, withStopIds, type RouteDraft } from './routeEdit';

const stop = (name: string, time: string, id = '', lat: number | null = 11, lng: number | null = 76.9) => ({
  id, name, lat, lng, scheduledTime: time,
});

const draft = (overrides: Partial<RouteDraft> = {}): RouteDraft => ({
  name: 'Gandhipuram – Campus',
  city: 'Coimbatore',
  active: true,
  guestFare: 40,
  stops: [stop('Gandhipuram', '07:00', 'gandhipuram'), stop('Amrita Campus', '08:00', 'campus')],
  ...overrides,
});

describe('stop IDs', () => {
  test('new stops get an ID from their name, unique in the route', () => {
    const stops = withStopIds([stop('Town Hall', '07:10', 'town-hall'), stop('Town Hall', '07:12'), stop('Ukkadam!', '07:15')]);
    expect(stops.map((s) => s.id)).toEqual(['town-hall', 'town-hall-2', 'ukkadam']);
    expect(slugify('  R.S. Puram  ')).toBe('r-s-puram');
    expect(slugify('நிறுத்தம்')).toBe('stop');
  });

  test('a renamed stop keeps its ID, so students who chose it keep it', () => {
    const [renamed] = withStopIds([{ ...stop('Gandhipuram Bus Stand', '07:00', 'gandhipuram') }]);
    expect(renamed.id).toBe('gandhipuram');
  });
});

describe('routeProblems', () => {
  test('a complete route has none', () => {
    expect(routeProblems(draft())).toEqual([]);
  });

  test('names everything missing or out of order, in plain words', () => {
    const problems = routeProblems(draft({
      name: ' ',
      guestFare: -1,
      stops: [stop('A', '07:30'), stop('', '7:15', '', null, null), stop('C', '07:10')],
    }));
    expect(problems).toEqual([
      'The route needs a name.',
      'Guest fare must be between ₹0 and ₹1000.',
      'Stop 2 needs a name.',
      'Stop 2 needs a position: click the map to place it.',
      'Stop 2 needs a time as HH:MM, for example 07:15.',
      'C is earlier than the stop before it. Stops go in travel order, ending at the campus.',
    ]);
  });
});

describe('buildPath', () => {
  test('turns an OSRM reply into the path, distances and off-road warnings', async () => {
    const path = await buildPath(
      [{ id: 'a', lat: 11, lng: 76.9 }, { id: 'b', lat: 10.99, lng: 76.9 }, { id: 'campus', lat: 10.9, lng: 76.9 }],
      async (url) => {
        expect(url).toContain('/route/v1/driving/76.9,11;76.9,10.99;76.9,10.9?');
        return {
          code: 'Ok',
          routes: [{ geometry: '_p~iF~ps|U_ulLnnqC', distance: 5300.4, legs: [{ distance: 1200.2 }, { distance: 4100.2 }] }],
          waypoints: [{ distance: 12 }, { distance: 327.4 }, { distance: 82 }],
        };
      },
    );
    expect(path.distanceFromStartM).toEqual([0, 1200, 5300]);
    expect(path.offRoad).toEqual([{ stopId: 'b', metres: 327 }, { stopId: 'campus', metres: 82 }]);

    const doc = routeDocument(draft({ stops: [stop('A', '07:00', 'a'), stop('B', '07:10', 'b'), stop('Campus', '07:30', 'campus')] }), path);
    expect(doc.stopIds).toEqual(['a', 'b', 'campus']);
    expect(doc.stops.map((s) => s.distanceFromStartM)).toEqual([0, 1200, 5300]);
  });

  test('explains when there is no road route', async () => {
    await expect(buildPath([{ id: 'a', lat: 0, lng: 0 }, { id: 'b', lat: 1, lng: 1 }], async () => ({ code: 'NoRoute' })))
      .rejects.toThrow('Could not find a road route through these stops (NoRoute).');
  });
});

describe('live positions', () => {
  const now = 1_800_000_000_000;
  test('the same states the student app shows', () => {
    const [bus] = parseLive({ 'bus-01': { lat: 1, lng: 2, updatedAt: now - 5000, status: 'running', tripId: 't' } });
    expect(liveState(bus, now)).toBe('live');
    expect(liveState({ ...bus, updatedAt: now - 31_000 }, now)).toBe('stale');
    expect(liveState({ ...bus, status: 'offline' }, now)).toBe('offline');
    expect(liveState({ ...bus, status: 'ended' }, now)).toBe('notRunning');
    expect(liveState({ ...bus, updatedAt: now - 3 * 3600_000 }, now)).toBe('notRunning');
    expect(parseLive({ bad: { lat: 'x' } })).toEqual([]);
    expect(describeAge(4000)).toBe('4 s ago');
    expect(describeAge(125_000)).toBe('2 min ago');
  });

  test('polylines decode with negative steps', () => {
    expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')).toEqual([[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
  });
});

describe('passes', () => {
  test('valid through the last day, then expired; none without a date', () => {
    expect(passState({ passValid: true, passValidUntil: '2026-10-12' }, '2026-10-12')).toBe('valid');
    expect(passState({ passValid: true, passValidUntil: '2026-10-12' }, '2026-10-13')).toBe('expired');
    expect(passState({ passValid: true, passValidUntil: null }, '2026-10-12')).toBe('none');
    expect(passState({ passValid: false, passValidUntil: '2027-01-01' }, '2026-10-12')).toBe('none');
  });
});
