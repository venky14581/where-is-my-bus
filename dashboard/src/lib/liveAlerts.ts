import type { DocumentData, Timestamp } from 'firebase/firestore';
import { ALERT_LABEL, type SafetyAlert } from './safety';

// What pops up on the office screen as things happen: SOS and safety alerts
// (safetyAlerts/{id}) and the riders' feed (alerts/{id}, written by
// functions/src/index.ts): trip started, running late, breakdown, delay.

export type Tone = 'danger' | 'warning' | 'info';

export interface OfficeToast {
  id: string;
  tone: Tone;
  title: string;
  body: string;
  /** Stays until the office closes it. */
  sticky: boolean;
  /** Where to look next, as a dashboard hash. */
  link: string;
}

const millis = (v: unknown) => (v && typeof (v as Timestamp).toMillis === 'function' ? (v as Timestamp).toMillis() : null);

/** A safety alert as a pop-up. SOS stays until closed. */
export function toastForSafety(a: SafetyAlert): OfficeToast {
  const where = [a.busNumber, a.routeName].filter(Boolean).join(' · ');
  const body = a.type === 'sos'
    ? `${where}. From ${a.fromRole === 'driver' ? 'the driver' : 'a student'}${a.fromName ? ` (${a.fromName})` : ''}.`
    : a.type === 'overspeed'
      ? `${where}. ${a.speedKmh ?? '?'} km/h in a ${a.limitKmh ?? '?'} km/h limit.`
      : `${where}. ${a.distanceM === null ? 'Away' : `${Math.round(a.distanceM)} m`} from its route.`;
  return {
    id: `safety:${a.id}`,
    tone: a.type === 'sos' ? 'danger' : 'warning',
    title: a.type === 'sos' ? 'SOS' : ALERT_LABEL[a.type],
    body,
    sticky: a.type === 'sos',
    link: '#/safety',
  };
}

/**
 * A riders' feed item as the office should read it, or null for the ones it
 * does not need (per-student reminders).
 */
export function toastForFeed(id: string, d: DocumentData): OfficeToast | null {
  const p = (d.params ?? {}) as Record<string, unknown>;
  const bus = String(p.busNumber ?? 'A bus');
  const route = typeof p.routeName === 'string' && p.routeName ? ` (${p.routeName})` : '';
  const base = { id: `feed:${id}`, sticky: false, link: '#/map' };
  switch (d.kind) {
    case 'tripStarted':
      return { ...base, tone: 'info', title: 'Trip started', body: `${bus}${route} is on its way.` };
    case 'delay':
      return { ...base, tone: 'warning', title: 'Running behind', body: `${bus} is about ${p.minutes ?? '?'} min behind schedule.` };
    case 'late':
      return { ...base, tone: 'warning', title: 'Driver reports: running late', body: `${bus}${route}.` };
    case 'breakdown':
      return { ...base, tone: 'danger', title: 'Driver reports: breakdown', body: `${bus}${route} has broken down.`, sticky: true };
    case 'announcement':
      return null; // sent by the office itself
    default:
      return null;
  }
}

/** Feed items written after [since] (ms), newest last. */
export function feedSince(items: { id: string; createdAt: unknown }[], since: number): string[] {
  return items
    .map((i) => ({ id: i.id, at: millis(i.createdAt) }))
    .filter((i): i is { id: string; at: number } => i.at !== null && i.at > since)
    .sort((a, b) => a.at - b.at)
    .map((i) => i.id);
}

/** Ids not seen before, marking them seen. */
export function takeNew(seen: Set<string>, ids: readonly string[]): string[] {
  const fresh = ids.filter((id) => !seen.has(id));
  for (const id of fresh) seen.add(id);
  return fresh;
}
