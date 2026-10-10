import { describe, expect, test } from 'vitest';

import { eventDetails, newShareToken, shareState } from './safety.js';

describe('trip links for parents', () => {
  const now = new Date('2026-10-12T07:30:00+05:30');
  const later = { expiresAt: new Date('2026-10-12T19:30:00+05:30') };

  test('work while the trip runs, and stop when it ends or the link expires', () => {
    expect(shareState(later, { status: 'running' }, now)).toBe('ok');
    expect(shareState(later, { status: 'ended' }, now)).toBe('ended');
    expect(shareState({ expiresAt: now }, { status: 'running' }, now)).toBe('ended');
    expect(shareState(null, { status: 'running' }, now)).toBe('notFound');
    expect(shareState(later, null, now)).toBe('notFound');
  });

  test('tokens are long and unguessable', () => {
    const a = newShareToken();
    expect(a).toMatch(/^[\w-]{22}$/);
    expect(newShareToken()).not.toBe(a);
  });
});

test("an event from the phone keeps only the numbers the office is shown", () => {
  expect(eventDetails({ speedKmh: 71.6, limitKmh: 60, lat: 11, note: 'x', distanceM: Number.NaN })).toEqual({ speedKmh: 72, limitKmh: 60 });
});
