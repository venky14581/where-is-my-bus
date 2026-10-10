// Who should hear about what. Pure functions, no Firebase, so every rule
// here is unit-tested in audience.test.ts.

export const TIME_ZONE = 'Asia/Kolkata';

export type AlertKind = 'tripStarted' | 'approaching' | 'delay' | 'late' | 'breakdown' | 'announcement';

/** A student's choices, stored at users/{uid}.alerts. */
export interface AlertPrefs {
  approaching: boolean;
  tripStarted: boolean;
  /** Delays, running late and breakdowns. */
  delays: boolean;
  announcements: boolean;
  /** Notify when the bus is this many stops away (1 to 3). */
  leadStops: number;
  /** ISO weekdays with no notifications: 1 = Monday ... 7 = Sunday. */
  quietDays: number[];
}

export const DEFAULT_PREFS: AlertPrefs = {
  approaching: true,
  tripStarted: true,
  delays: true,
  announcements: true,
  leadStops: 2,
  quietDays: [],
};

/** Missing or malformed settings fall back to the defaults, field by field. */
export function prefsOf(raw: unknown): AlertPrefs {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const bool = (key: keyof AlertPrefs) => (typeof r[key] === 'boolean' ? (r[key] as boolean) : (DEFAULT_PREFS[key] as boolean));
  const lead = typeof r.leadStops === 'number' ? Math.round(r.leadStops) : DEFAULT_PREFS.leadStops;
  const quiet = Array.isArray(r.quietDays)
    ? r.quietDays.filter((d): d is number => Number.isInteger(d) && d >= 1 && d <= 7)
    : DEFAULT_PREFS.quietDays;
  return {
    approaching: bool('approaching'),
    tripStarted: bool('tripStarted'),
    delays: bool('delays'),
    announcements: bool('announcements'),
    leadStops: Math.min(3, Math.max(1, lead)),
    quietDays: quiet,
  };
}

export function wants(prefs: AlertPrefs, kind: AlertKind): boolean {
  switch (kind) {
    case 'approaching':
      return prefs.approaching;
    case 'tripStarted':
      return prefs.tripStarted;
    case 'delay':
    case 'late':
    case 'breakdown':
      return prefs.delays;
    case 'announcement':
      return prefs.announcements;
  }
}

const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

/** ISO weekday of [when] on the campus clock. */
export function weekdayAt(when: Date, timeZone = TIME_ZONE): number {
  const name = new Intl.DateTimeFormat('en-US', { weekday: 'short', timeZone }).format(when);
  return WEEKDAYS[name];
}

/**
 * Whether to push [kind] to someone with [prefs] at [when]. Breakdowns get
 * through quiet days: a student may still be about to travel.
 */
export function shouldPush(prefs: AlertPrefs, kind: AlertKind, when: Date): boolean {
  if (!wants(prefs, kind)) return false;
  return kind === 'breakdown' || !prefs.quietDays.includes(weekdayAt(when));
}

export interface Stop {
  id: string;
  scheduledTime: string;
}

export interface Rider {
  uid: string;
  stopId: string | null;
  prefs: AlertPrefs;
}

export type Direction = 'toCampus' | 'fromCampus';

export function parseMinutes(hhmm: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

export interface Approaching {
  uid: string;
  stopsAway: number;
  /** Scheduled minutes from the reached stop to theirs; null in the evening. */
  minutes: number | null;
}

/**
 * Riders to tell "your bus is coming" now that the bus has reached
 * [reachedStopId]: their stop is still ahead and within their chosen number
 * of stops, or within [withinMinutes] by the timetable (morning only, as the
 * timetable holds morning times).
 */
export function approachingRiders(options: {
  stops: Stop[]; // in route order, first stop to campus
  direction: Direction;
  reachedStopId: string;
  riders: Rider[];
  withinMinutes?: number;
}): Approaching[] {
  const { direction, reachedStopId, riders, withinMinutes = 5 } = options;
  const order = direction === 'toCampus' ? options.stops : [...options.stops].reverse();
  const reached = order.findIndex((s) => s.id === reachedStopId);
  if (reached < 0) return [];

  const result: Approaching[] = [];
  for (const rider of riders) {
    const index = order.findIndex((s) => s.id === rider.stopId);
    if (index <= reached) continue; // passed, at it now, or not on this route
    const stopsAway = index - reached;
    let minutes: number | null = null;
    if (direction === 'toCampus') {
      const from = parseMinutes(order[reached].scheduledTime);
      const to = parseMinutes(order[index].scheduledTime);
      if (from !== null && to !== null && to >= from) minutes = to - from;
    }
    const close = stopsAway <= rider.prefs.leadStops || (minutes !== null && minutes <= withinMinutes);
    if (close) result.push({ uid: rider.uid, stopsAway, minutes });
  }
  return result;
}

/**
 * Minutes behind the timetable at a stop, on the campus clock. Null when
 * there is no usable scheduled time.
 */
export function minutesLate(options: { tripDate: string; scheduledTime: string; arrivedAt: Date }): number | null {
  const minutes = parseMinutes(options.scheduledTime);
  if (minutes === null || !/^\d{4}-\d{2}-\d{2}$/.test(options.tripDate)) return null;
  const hh = String(Math.floor(minutes / 60)).padStart(2, '0');
  const mm = String(minutes % 60).padStart(2, '0');
  // India has no daylight saving, so a fixed offset is exact.
  const scheduled = new Date(`${options.tripDate}T${hh}:${mm}:00+05:30`);
  return Math.floor((options.arrivedAt.getTime() - scheduled.getTime()) / 60000);
}

/**
 * Tell riders about a delay when it first passes [threshold] minutes, and
 * again each time it grows by another [step], not at every stop.
 */
export function shouldAlertDelay(late: number, alreadyAlerted: number, threshold = 10, step = 10): boolean {
  if (late < threshold) return false;
  return alreadyAlerted === 0 || late >= alreadyAlerted + step;
}
