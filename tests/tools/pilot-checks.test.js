import { describe, expect, test } from 'vitest';

import { decodePolyline, metresFromPath, pilotChecks } from '../../scripts/pilot-checks.mjs';

// Google's documented example polyline.
test('decodes a road path', () => {
  expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')).toEqual([[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
});

test('distance from a path, to the nearest segment', () => {
  const path = [[11, 76.96], [10.99, 76.96]];
  expect(metresFromPath([10.995, 76.96], path)).toBeLessThan(1);
  expect(metresFromPath([10.995, 76.961], path)).toBeCloseTo(109, -1);
  expect(metresFromPath([11.005, 76.96], path)).toBeCloseTo(553, -1); // beyond the end
});

// A straight road south along 76.96, encoded.
const encode = (points) => {
  let out = '';
  let prev = [0, 0];
  const one = (v) => {
    let n = v < 0 ? ~(v << 1) : v << 1;
    let s = '';
    while (n >= 0x20) {
      s += String.fromCharCode((0x20 | (n & 0x1f)) + 63);
      n >>= 5;
    }
    return s + String.fromCharCode(n + 63);
  };
  for (const [lat, lng] of points) {
    const e = [Math.round(lat * 1e5), Math.round(lng * 1e5)];
    out += one(e[0] - prev[0]) + one(e[1] - prev[1]);
    prev = e;
  }
  return out;
};

function project(overrides = {}) {
  const stops = [
    { id: 'a', name: 'Town Hall', lat: 11.0, lng: 76.96, scheduledTime: '07:00' },
    { id: 'campus', name: 'Campus', lat: 10.98, lng: 76.96, scheduledTime: '07:30' },
  ];
  return {
    routes: [{ id: 'r1', name: 'Town – Campus', active: true, stops, stopIds: ['a', 'campus'], path: encode([[11.0, 76.96], [10.98, 76.96]]), guestFare: 40 }],
    buses: [{ id: 'bus-01', number: 'TN 37 AB 1201', routeId: 'r1', driverId: 'd1' }],
    users: [{ id: 'd1', role: 'driver', name: 'Murugan', driverId: 'DRV001' }, { id: 'o1', role: 'office', name: 'Office' }],
    busDrivers: { 'bus-01': 'd1' },
    officeUids: { o1: true },
    settings: { booking: { opensAt: '18:00', closesMinutesBefore: 30 }, safety: { speedLimitKmh: 55 } },
    segmentTimes: { r1: { source: 'recorded', trainedOn: { trips: 40 } } },
    routeAccess: { r1: { acceptsFrom: [] } },
    ...overrides,
  };
}

const levels = (findings) => findings.map((f) => f.level);

describe('pilot checks', () => {
  test('a ready project: everything ok', () => {
    const findings = pilotChecks(project());
    expect(levels(findings).every((l) => l === 'ok')).toBe(true);
    expect(findings.map((f) => f.area)).toEqual(['Routes', 'Buses', 'Office', 'Settings', 'Settings', 'Arrival times']);
  });

  test('a stop too far from the road to be recorded must be fixed', () => {
    const p = project();
    p.routes[0].stops[0] = { ...p.routes[0].stops[0], lng: 76.962 }; // about 218 m east
    const [route] = pilotChecks(p);
    expect(route.level).toBe('fail');
    expect(route.message).toMatch(/Town Hall 2\d\d m from the road\. The driver's phone records a stop within 80 m/);
  });

  test('a driver whose phone could not send, an office without the live map, a route not ending at campus', () => {
    const p = project({ busDrivers: {}, officeUids: {} });
    p.routes[0].stops = [...p.routes[0].stops].reverse();
    p.routes[0].stopIds = ['campus', 'a'];
    const fails = pilotChecks(p).filter((f) => f.level === 'fail').map((f) => f.message);
    expect(fails).toEqual([
      'Town – Campus: the last stop is not the campus; Town Hall is not timed after Campus.',
      expect.stringMatching(/^TN 37 AB 1201: the live-position permission \(busDrivers\) does not match/),
      'Office is not in officeUids, so the live map stays empty for them.',
    ]);
  });

  test('worth a look: synthetic learned times, defaults, no fare, unassigned bus', () => {
    const p = project({
      settings: {},
      segmentTimes: { r1: { source: 'synthetic' } },
      buses: [{ id: 'bus-02', number: 'TN 37 AB 1202', routeId: 'r1', driverId: null }],
    });
    p.routes[0].guestFare = null;
    const warns = pilotChecks(p).filter((f) => f.level === 'warn').map((f) => f.message);
    expect(warns).toEqual([
      'Town – Campus: no guest fare, so no evening seats can be booked on it.',
      'TN 37 AB 1202: no driver assigned.',
      'Booking window not set; the defaults (opens 18:00, closes 30 min before) apply.',
      'Speed limit not set; 60 km/h applies.',
      expect.stringMatching(/^Town – Campus: learned times are from synthetic trips\. Remove them for the pilot/),
    ]);
  });
});
