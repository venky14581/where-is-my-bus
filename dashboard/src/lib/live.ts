// What a `live/{busId}` node means. Same rules as the student app
// (app/lib/features/live/domain/live_bus.dart); keep them in step.

export type LiveState = 'live' | 'stale' | 'offline' | 'notRunning';

export interface LiveBus {
  busId: string;
  lat: number;
  lng: number;
  updatedAt: number;
  status: string;
  tripId: string | null;
  speedMps: number;
}

export const STALE_AFTER_MS = 30_000;
export const NOT_RUNNING_AFTER_MS = 2 * 60 * 60_000;

export function parseLive(value: unknown): LiveBus[] {
  if (!value || typeof value !== 'object') return [];
  const result: LiveBus[] = [];
  for (const [busId, raw] of Object.entries(value as Record<string, unknown>)) {
    const v = raw as Record<string, unknown> | null;
    if (!v || typeof v.lat !== 'number' || typeof v.lng !== 'number' || typeof v.updatedAt !== 'number' || typeof v.status !== 'string') continue;
    result.push({
      busId,
      lat: v.lat,
      lng: v.lng,
      updatedAt: v.updatedAt,
      status: v.status,
      tripId: typeof v.tripId === 'string' ? v.tripId : null,
      speedMps: typeof v.speed === 'number' ? v.speed : 0,
    });
  }
  return result;
}

export function liveState(bus: LiveBus | undefined, serverNow: number): LiveState {
  if (!bus || bus.status === 'ended') return 'notRunning';
  const age = serverNow - bus.updatedAt;
  if (age > NOT_RUNNING_AFTER_MS) return 'notRunning';
  if (bus.status === 'offline') return 'offline';
  if (age > STALE_AFTER_MS) return 'stale';
  return 'live';
}

export function describeAge(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return `${s} s ago`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m} min ago` : `${Math.floor(m / 60)} h ${m % 60} min ago`;
}

export const STATE_LABEL: Record<LiveState, string> = {
  live: 'Live',
  stale: 'Weak signal',
  offline: 'Offline',
  notRunning: 'Not running',
};
