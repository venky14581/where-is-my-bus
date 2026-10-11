import { Timestamp } from 'firebase/firestore';
import { describe, expect, test } from 'vitest';

import { feedSince, takeNew, toastForFeed, toastForSafety } from './liveAlerts';
import type { SafetyAlert } from './safety';

const alert = (over: Partial<SafetyAlert> = {}): SafetyAlert => ({
  id: 'a1', type: 'sos', status: 'open', tripId: 't', busNumber: 'TN 37 AB 1201', routeName: 'Gandhipuram – Campus',
  driverName: 'Murugan S', fromRole: 'student', fromName: 'Asha', lat: 11, lng: 76.9, speedKmh: null, limitKmh: null,
  distanceM: null, at: 1, acknowledgedAt: null, ...over,
});

describe('office pop-ups', () => {
  test('an SOS is urgent and stays; overspeed is a warning that fades', () => {
    const sos = toastForSafety(alert());
    expect(sos).toMatchObject({ tone: 'danger', title: 'SOS', sticky: true, link: '#/safety' });
    expect(sos.body).toBe('TN 37 AB 1201 · Gandhipuram – Campus. From a student (Asha).');
    const fast = toastForSafety(alert({ type: 'overspeed', speedKmh: 72, limitKmh: 60 }));
    expect(fast).toMatchObject({ tone: 'warning', title: 'Overspeeding', sticky: false });
    expect(fast.body).toContain('72 km/h in a 60 km/h limit');
  });

  test("drivers' reports and trips reach the office; its own announcements do not", () => {
    const params = { busNumber: 'TN 37 AB 1201', routeName: 'Gandhipuram – Campus' };
    expect(toastForFeed('f1', { kind: 'breakdown', params })).toMatchObject({ tone: 'danger', sticky: true, title: 'Driver reports: breakdown' });
    expect(toastForFeed('f2', { kind: 'late', params })?.title).toBe('Driver reports: running late');
    expect(toastForFeed('f3', { kind: 'tripStarted', params })?.body).toBe('TN 37 AB 1201 (Gandhipuram – Campus) is on its way.');
    expect(toastForFeed('f4', { kind: 'delay', params: { ...params, minutes: 12 } })?.body).toContain('about 12 min behind');
    expect(toastForFeed('f5', { kind: 'announcement', params: { title: 'x' } })).toBeNull();
  });

  test('only what arrives after the page opened, once each', () => {
    const items = [
      { id: 'old', createdAt: Timestamp.fromMillis(900) },
      { id: 'b', createdAt: Timestamp.fromMillis(1200) },
      { id: 'a', createdAt: Timestamp.fromMillis(1100) },
      { id: 'pending', createdAt: null },
    ];
    expect(feedSince(items, 1000)).toEqual(['a', 'b']);
    const seen = new Set<string>();
    expect(takeNew(seen, ['a', 'b'])).toEqual(['a', 'b']);
    expect(takeNew(seen, ['a', 'b', 'c'])).toEqual(['c']);
  });
});
