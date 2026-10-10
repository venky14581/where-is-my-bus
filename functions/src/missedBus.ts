// Missed-bus help: the rules for riding another college bus, kept free of
// Firebase so they can be unit tested. Used by holds.ts and boarding.ts.

export type Direction = 'toCampus' | 'fromCampus';

/** A hold's life: a seat is counted while `held` or `boarded`. */
export type HoldStatus = 'held' | 'boarded' | 'cancelled' | 'missed';

export const countsAsSeat = (status: unknown) => status === 'held' || status === 'boarded';

/** Route stops are stored towards campus; evening trips run them backwards. */
export function travelOrder<T>(stops: readonly T[], direction: Direction): T[] {
  return direction === 'toCampus' ? [...stops] : [...stops].reverse();
}

/** Where a rider can get on: every stop except where the trip ends. */
export function pickupStopIds(stopIds: readonly string[], direction: Direction): string[] {
  return travelOrder(stopIds, direction).slice(0, -1);
}

/**
 * The office decides which routes' riders a route may carry
 * (`routeAccess/{routeId}.acceptsFrom`). A student's own route is not an
 * alternate.
 */
export function mayRideAlternate(tripRouteId: string, studentRouteId: string | null, acceptsFrom: unknown): boolean {
  if (!studentRouteId || studentRouteId === tripRouteId) return false;
  return Array.isArray(acceptsFrom) && acceptsFrom.includes(studentRouteId);
}

/**
 * Whether the bus has already gone past [stopId]: a stop time is recorded
 * there or at any stop after it.
 */
export function hasPassed(stopIds: readonly string[], direction: Direction, stopId: string, recorded: Iterable<string>): boolean {
  const order = travelOrder(stopIds, direction);
  const at = order.indexOf(stopId);
  if (at < 0) return true;
  for (const id of recorded) {
    if (order.indexOf(id) >= at) return true;
  }
  return false;
}

/**
 * Holds whose pickup stop is behind the bus once it reaches [reachedStopId].
 * A hold at the stop just reached stays: the rider may be boarding now.
 */
export function holdsLeftBehind(options: {
  stopIds: readonly string[];
  direction: Direction;
  reachedStopId: string;
  holds: readonly { uid: string; stopId: string }[];
}): string[] {
  const order = travelOrder(options.stopIds, options.direction);
  const reached = order.indexOf(options.reachedStopId);
  if (reached < 0) return [];
  return options.holds
    .filter((h) => {
      const at = order.indexOf(h.stopId);
      return at >= 0 && at < reached;
    })
    .map((h) => h.uid);
}

/** Today's date on the campus clock, as trips are named. */
export function campusDate(now: Date): string {
  return now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
}
