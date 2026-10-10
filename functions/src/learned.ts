// Learned arrival time (Module 11): the rules, kept free of Firebase so they
// can be unit tested. The app has the same rules in
// app/lib/features/eta/domain/learned_times.dart; both test the same example.

/** Seconds per stretch between neighbouring stops, in route order, by weekday ("1" = Monday) and slot ("07:30"). */
export type SegmentTable = Record<string, Record<string, number[]>>;

/** segmentTimes/{routeId}, written from ml/train.py's output. */
export interface LearnedTimes {
  slotMinutes?: number;
  toCampus?: SegmentTable | null;
  fromCampus?: SegmentTable | null;
  delayByWeekday?: Record<string, { minutes: number; trips: number }>;
}

/** conditions/{date}: how today's buses compare with what was expected. */
export interface Conditions {
  ratioSum?: number;
  count?: number;
}

const IST_OFFSET_MS = 5.5 * 3600_000;
/** A slot this far from the time asked for is too far to trust. */
const MAX_SLOT_DISTANCE_MIN = 60;
/** Today's slowness counts once this many stretches are measured... */
export const MIN_STRETCHES_FOR_FACTOR = 3;
/** ...and stretches estimates by at most this much. */
export const MAX_FACTOR = 1.5;
/** Minutes spare between reaching the stop and the bus arriving. */
export const LEAVE_BUFFER_MIN = 2;

/** Weekday (1 = Monday) and minute of the day on the campus clock. */
export function campusClock(at: Date): { weekday: number; minute: number } {
  const local = new Date(at.getTime() + IST_OFFSET_MS);
  const day = local.getUTCDay();
  return { weekday: day === 0 ? 7 : day, minute: local.getUTCHours() * 60 + local.getUTCMinutes() };
}

export function slotKey(minuteOfDay: number, slotMinutes = 30): string {
  const start = Math.floor(minuteOfDay / slotMinutes) * slotMinutes;
  return `${String(Math.floor(start / 60)).padStart(2, '0')}:${String(start % 60).padStart(2, '0')}`;
}

const minutesOf = (hhmm: string): number => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

/**
 * Seconds per stretch for a trip running [direction] at [at], from the
 * nearest slot on the same weekday. Null when there is nothing learned
 * close enough, or it does not fit a route of [stopCount] stops.
 */
export function learnedSegments(
  learned: LearnedTimes | undefined,
  direction: 'toCampus' | 'fromCampus',
  at: Date,
  stopCount: number,
): number[] | null {
  const byDay = learned?.[direction]?.[String(campusClock(at).weekday)];
  if (!byDay) return null;
  const slotMinutes = learned?.slotMinutes ?? 30;
  const target = Math.floor(campusClock(at).minute / slotMinutes) * slotMinutes;
  let best: { key: string; distance: number } | null = null;
  for (const key of Object.keys(byDay)) {
    const distance = Math.abs(minutesOf(key) - target);
    if (!best || distance < best.distance || (distance === best.distance && key < best.key)) best = { key, distance };
  }
  if (!best || best.distance > MAX_SLOT_DISTANCE_MIN) return null;
  const segments = byDay[best.key];
  return Array.isArray(segments) && segments.length === stopCount - 1 && segments.every((s) => typeof s === 'number' && s > 0)
    ? segments
    : null;
}

/** How much slower than expected today's buses are running: 1 to MAX_FACTOR. */
export function trafficFactor(conditions: Conditions | undefined): number {
  const count = conditions?.count ?? 0;
  if (count < MIN_STRETCHES_FOR_FACTOR) return 1;
  return Math.min(MAX_FACTOR, Math.max(1, (conditions?.ratioSum ?? count) / count));
}

/**
 * Expected seconds from stop index [from] to stop index [to] (either order),
 * from learned stretches or else the timetable gaps, times [factor].
 */
export function secondsBetween(
  from: number,
  to: number,
  options: { segments: number[] | null; timetableMinutes: (number | null)[]; factor?: number },
): number | null {
  const [a, b] = from < to ? [from, to] : [to, from];
  let total = 0;
  for (let i = a; i < b; i++) {
    const learned = options.segments?.[i];
    if (learned !== undefined) {
      total += learned;
      continue;
    }
    const x = options.timetableMinutes[i];
    const y = options.timetableMinutes[i + 1];
    if (x == null || y == null) return null;
    total += Math.abs(y - x) * 60;
  }
  return total * (options.factor ?? 1);
}

/** When to leave home to be at the stop [LEAVE_BUFFER_MIN] before the bus. */
export function leaveAt(busAtStop: Date, walkMinutes: number): Date {
  return new Date(busAtStop.getTime() - (walkMinutes + LEAVE_BUFFER_MIN) * 60_000);
}
