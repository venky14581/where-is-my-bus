// Office reports (Module 12), worked out from trips, their stop times and
// boardings, and evening bookings. Kept free of Firebase so they can be
// tested. Only stop times are stored, never every position (per project spec), so
// a trip's path between stops is estimated from them.

export interface ReportStop {
  id: string;
  name: string;
  scheduledTime: string;
  /** Along the road from the first stop, from the route's path. */
  distanceFromStartM?: number;
}

export interface ReportRoute {
  id: string;
  name: string;
  stops: ReportStop[];
}

export type BoardingType = 'pass' | 'alternate' | 'guest';

export interface TripRecord {
  id: string;
  routeId: string;
  busId: string;
  date: string;
  direction: 'toCampus' | 'fromCampus';
  /** Recorded arrival at each stop, ms since the epoch. */
  stopTimes: Record<string, number>;
  boardings: { type: BoardingType; stopId: string | null }[];
}

export interface BookingRecord {
  tripId: string;
  routeId: string;
  date: string;
  fare: number;
  status: string;
}

/** A within this many minutes of the timetable at campus counts as on time. */
export const ON_TIME_MINUTES = 5;

/** A campus-clock time on a date (India, no daylight saving), in ms. */
export function campusTime(date: string, hhmm: string): number | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{1,2}:\d{2}$/.test(hhmm)) return null;
  return Date.parse(`${date}T${hhmm.padStart(5, '0')}:00+05:30`);
}

const round1 = (x: number) => Math.round(x * 10) / 10;
const average = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);

/** Minutes late at campus for a morning trip, or null if not recorded. */
export function minutesLateAtCampus(trip: TripRecord, route: ReportRoute | undefined): number | null {
  const campus = route?.stops.at(-1);
  if (trip.direction !== 'toCampus' || !campus) return null;
  const arrived = trip.stopTimes[campus.id];
  const due = campusTime(trip.date, campus.scheduledTime);
  return arrived === undefined || due === null ? null : (arrived - due) / 60_000;
}

export interface PunctualityRow {
  routeId: string;
  routeName: string;
  trips: number;
  averageLateMinutes: number | null;
  onTimeShare: number | null;
  worstLateMinutes: number | null;
}

/** Scheduled against actual at campus, per route, over morning trips. */
export function punctuality(trips: TripRecord[], routes: ReportRoute[]): PunctualityRow[] {
  return routes.map((route) => {
    const late = trips
      .filter((t) => t.routeId === route.id)
      .map((t) => minutesLateAtCampus(t, route))
      .filter((m): m is number => m !== null);
    const avg = average(late);
    return {
      routeId: route.id,
      routeName: route.name,
      trips: late.length,
      averageLateMinutes: avg === null ? null : round1(avg),
      onTimeShare: late.length ? late.filter((m) => m <= ON_TIME_MINUTES).length / late.length : null,
      worstLateMinutes: late.length ? round1(Math.max(...late)) : null,
    };
  });
}

export interface RidershipDay {
  date: string;
  routeId: string;
  pass: number;
  alternate: number;
  guest: number;
}

/** Riders per day and route, from pass scans and guest tickets. */
export function ridershipByDay(trips: TripRecord[]): RidershipDay[] {
  const rows = new Map<string, RidershipDay>();
  for (const trip of trips) {
    const key = `${trip.date}|${trip.routeId}`;
    const row = rows.get(key) ?? { date: trip.date, routeId: trip.routeId, pass: 0, alternate: 0, guest: 0 };
    for (const b of trip.boardings) row[b.type]++;
    rows.set(key, row);
  }
  return [...rows.values()].sort((a, b) => a.date.localeCompare(b.date) || a.routeId.localeCompare(b.routeId));
}

export interface StopRidership {
  routeId: string;
  stopId: string;
  stopName: string;
  riders: number;
  /** Riders per morning trip of the route that boarded here. */
  perTrip: number;
}

/** Morning boardings at each stop (the campus excluded: nobody boards there in the morning). */
export function ridershipByStop(trips: TripRecord[], routes: ReportRoute[]): StopRidership[] {
  const rows: StopRidership[] = [];
  for (const route of routes) {
    const morning = trips.filter((t) => t.routeId === route.id && t.direction === 'toCampus');
    for (const stop of route.stops.slice(0, -1)) {
      const riders = morning.reduce((n, t) => n + t.boardings.filter((b) => b.stopId === stop.id).length, 0);
      rows.push({
        routeId: route.id,
        stopId: stop.id,
        stopName: stop.name,
        riders,
        perTrip: morning.length ? round1(riders / morning.length) : 0,
      });
    }
  }
  return rows;
}

export interface GuestDay {
  date: string;
  routeId: string;
  guests: number;
  fares: number;
  noShows: number;
}

/**
 * Guest riders and fares collected per day and route. A paid seat never
 * scanned on a past day is a no-show; the fare is kept (features document).
 */
export function guestBookings(bookings: BookingRecord[], today: string): GuestDay[] {
  const rows = new Map<string, GuestDay>();
  for (const b of bookings) {
    if (b.status !== 'confirmed' && b.status !== 'used') continue;
    const key = `${b.date}|${b.routeId}`;
    const row = rows.get(key) ?? { date: b.date, routeId: b.routeId, guests: 0, fares: 0, noShows: 0 };
    row.guests++;
    row.fares += b.fare;
    if (b.status === 'confirmed' && b.date < today) row.noShows++;
    rows.set(key, row);
  }
  return [...rows.values()].sort((a, b) => a.date.localeCompare(b.date) || a.routeId.localeCompare(b.routeId));
}

export interface Suggestions {
  /** Stops where hardly anyone boards. */
  quietStops: StopRidership[];
  /** Routes whose buses are often nearly full. */
  fullRoutes: { routeId: string; fullShare: number; trips: number }[];
}

/** Needs this many morning trips of a route before saying anything about it. */
export const MIN_TRIPS_FOR_SUGGESTION = 5;

export function routeSuggestions(
  trips: TripRecord[],
  routes: ReportRoute[],
  capacityOf: (busId: string) => number,
  options: { quietPerTrip?: number; fullLoad?: number; fullShare?: number } = {},
): Suggestions {
  const { quietPerTrip = 1, fullLoad = 0.9, fullShare = 0.5 } = options;
  const quietStops: StopRidership[] = [];
  const fullRoutes: Suggestions['fullRoutes'] = [];
  for (const route of routes) {
    const morning = trips.filter((t) => t.routeId === route.id && t.direction === 'toCampus');
    if (morning.length < MIN_TRIPS_FOR_SUGGESTION) continue;
    quietStops.push(...ridershipByStop(morning, [route]).filter((s) => s.perTrip < quietPerTrip));
    const full = morning.filter((t) => {
      const capacity = capacityOf(t.busId);
      return capacity > 0 && t.boardings.length >= capacity * fullLoad;
    }).length;
    if (full / morning.length >= fullShare) fullRoutes.push({ routeId: route.id, fullShare: full / morning.length, trips: morning.length });
  }
  return { quietStops, fullRoutes };
}

/**
 * Where the bus probably was at [at], along the road: between the two
 * recorded stops either side, in proportion to time. Null outside the
 * recorded part of the trip.
 */
export function alongAt(trip: TripRecord, route: ReportRoute, at: number): number | null {
  const points = route.stops
    .filter((s) => trip.stopTimes[s.id] !== undefined && s.distanceFromStartM !== undefined)
    .map((s) => ({ t: trip.stopTimes[s.id], along: s.distanceFromStartM! }))
    .sort((a, b) => a.t - b.t);
  if (points.length === 0 || at < points[0].t || at > points.at(-1)!.t) return null;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    if (at <= b.t) return b.t === a.t ? b.along : a.along + ((at - a.t) / (b.t - a.t)) * (b.along - a.along);
  }
  return points.at(-1)!.along;
}

/** The point [metres] along a path of [lat, lng] points. */
export function pointAlong(path: [number, number][], metres: number): [number, number] | null {
  if (path.length === 0) return null;
  let walked = 0;
  for (let i = 1; i < path.length; i++) {
    const step = metresBetween(path[i - 1], path[i]);
    if (walked + step >= metres) {
      const f = step === 0 ? 0 : (metres - walked) / step;
      return [path[i - 1][0] + f * (path[i][0] - path[i - 1][0]), path[i - 1][1] + f * (path[i][1] - path[i - 1][1])];
    }
    walked += step;
  }
  return path.at(-1)!;
}

export function metresBetween(a: [number, number], b: [number, number]): number {
  const rad = Math.PI / 180;
  const dLat = (b[0] - a[0]) * rad;
  const dLng = (b[1] - a[1]) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

/** The last [days] dates up to and including [today] (YYYY-MM-DD). */
export function dateRange(today: string, days: number): { from: string; to: string } {
  const d = new Date(`${today}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() - (days - 1));
  return { from: d.toISOString().slice(0, 10), to: today };
}

export interface TrackingRow {
  tripId: string;
  date: string;
  routeId: string;
  busId: string;
  direction: TripRecord['direction'];
  recorded: number;
  expected: number;
  /** Names of the stops no time was recorded for, in travel order. */
  missing: string[];
}

export interface TrackingDay {
  date: string;
  trips: number;
  /** Trips with every stop recorded. */
  complete: number;
  /** Stops recorded out of stops on the routes driven. */
  recordedShare: number;
}

/** A pilot target: a phone that tracks properly records nearly every stop. */
export const TRACKING_TARGET = 0.95;

/**
 * How well the drivers' phones tracked: every stop a trip passes should get
 * a time. Missing ones point at a phone that stopped sending (screen off,
 * dead zone, app closed) or a stop placed off the road.
 */
export function trackingHealth(trips: TripRecord[], routes: ReportRoute[]): { rows: TrackingRow[]; days: TrackingDay[]; stops: { routeId: string; stopName: string; missed: number; of: number }[] } {
  const rows: TrackingRow[] = [];
  for (const trip of trips) {
    const route = routes.find((r) => r.id === trip.routeId);
    if (!route) continue;
    const ordered = trip.direction === 'toCampus' ? route.stops : [...route.stops].reverse();
    rows.push({
      tripId: trip.id,
      date: trip.date,
      routeId: trip.routeId,
      busId: trip.busId,
      direction: trip.direction,
      recorded: ordered.filter((s) => trip.stopTimes[s.id] !== undefined).length,
      expected: ordered.length,
      missing: ordered.filter((s) => trip.stopTimes[s.id] === undefined).map((s) => s.name),
    });
  }
  rows.sort((a, b) => a.date.localeCompare(b.date) || a.tripId.localeCompare(b.tripId));
  const days = [...new Set(rows.map((r) => r.date))].map((date) => {
    const of = rows.filter((r) => r.date === date);
    const expected = of.reduce((n, r) => n + r.expected, 0);
    return {
      date,
      trips: of.length,
      complete: of.filter((r) => r.recorded === r.expected).length,
      recordedShare: expected ? of.reduce((n, r) => n + r.recorded, 0) / expected : 0,
    };
  });
  // Stops missed again and again are more likely off the road than a phone problem.
  const stops: { routeId: string; stopName: string; missed: number; of: number }[] = [];
  for (const route of routes) {
    const driven = rows.filter((r) => r.routeId === route.id);
    for (const stop of route.stops) {
      const missed = driven.filter((r) => r.missing.includes(stop.name)).length;
      if (missed) stops.push({ routeId: route.id, stopName: stop.name, missed, of: driven.length });
    }
  }
  stops.sort((a, b) => b.missed / b.of - a.missed / a.of);
  return { rows, days, stops };
}
