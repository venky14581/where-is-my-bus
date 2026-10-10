// Editing a route's stops in the dashboard. Pure functions; see
// routeEdit.test.ts.

export interface StopDraft {
  /** Stable ID saved on students' profiles. Empty for a new stop until saved. */
  id: string;
  name: string;
  lat: number | null;
  lng: number | null;
  /** Morning time at this stop, HH:mm. */
  scheduledTime: string;
}

export interface RouteDraft {
  name: string;
  city: string;
  active: boolean;
  /** Guest fare in rupees for evening seat booking (Module 10). */
  guestFare: number | null;
  stops: StopDraft[];
}

export function slugify(name: string): string {
  return (
    name
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 40) || 'stop'
  );
}

/**
 * Gives new stops an ID from their name, unique within the route. Existing
 * stops keep theirs even when renamed: students' saved stops point at it.
 */
export function withStopIds(stops: StopDraft[]): StopDraft[] {
  const used = new Set(stops.map((s) => s.id).filter(Boolean));
  return stops.map((stop) => {
    if (stop.id) return stop;
    const base = slugify(stop.name);
    let id = base;
    for (let n = 2; used.has(id); n++) id = `${base}-${n}`;
    used.add(id);
    return { ...stop, id };
  });
}

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

/** Everything that would stop the route from being saved, in plain words. */
export function routeProblems(route: RouteDraft): string[] {
  const problems: string[] = [];
  if (!route.name.trim()) problems.push('The route needs a name.');
  if (!route.city.trim()) problems.push('The route needs a city.');
  if (route.stops.length < 2) problems.push('A route needs at least two stops: where it starts and the campus.');
  if (route.guestFare !== null && (!Number.isFinite(route.guestFare) || route.guestFare < 0 || route.guestFare > 1000)) {
    problems.push('Guest fare must be between ₹0 and ₹1000.');
  }
  route.stops.forEach((stop, i) => {
    const label = stop.name.trim() || `Stop ${i + 1}`;
    if (!stop.name.trim()) problems.push(`Stop ${i + 1} needs a name.`);
    if (stop.lat === null || stop.lng === null || Math.abs(stop.lat) > 90 || Math.abs(stop.lng) > 180) {
      problems.push(`${label} needs a position: click the map to place it.`);
    }
    if (!TIME.test(stop.scheduledTime)) problems.push(`${label} needs a time as HH:MM, for example 07:15.`);
  });
  // Compare with the latest valid time so far, so one bad time in between
  // does not hide an out-of-order stop.
  let latest: string | null = null;
  route.stops.forEach((stop, i) => {
    if (!TIME.test(stop.scheduledTime)) return;
    if (latest !== null && stop.scheduledTime < latest) {
      problems.push(`${stop.name || `Stop ${i + 1}`} is earlier than the stop before it. Stops go in travel order, ending at the campus.`);
    } else {
      latest = stop.scheduledTime;
    }
  });
  return problems;
}

export interface RoutePath {
  polyline: string;
  distanceM: number;
  distanceFromStartM: number[];
  /** Stops further than [OFF_ROAD_M] from the road: the phone will never record them. */
  offRoad: { stopId: string; metres: number }[];
}

/** The driver's phone records a stop within 80 m; warn well before that. */
export const OFF_ROAD_M = 50;

interface OsrmResponse {
  code: string;
  message?: string;
  routes?: { geometry: string; distance: number; legs: { distance: number }[] }[];
  waypoints?: { distance: number }[];
}

/** Road path through the stops in order, from an OSRM server. */
export async function buildPath(
  stops: { id: string; lat: number; lng: number }[],
  fetchJson: (url: string) => Promise<OsrmResponse> = async (url) => (await fetch(url)).json(),
  server = 'https://router.project-osrm.org',
): Promise<RoutePath> {
  const coords = stops.map((s) => `${s.lng},${s.lat}`).join(';');
  const body = await fetchJson(`${server}/route/v1/driving/${coords}?overview=full&geometries=polyline`);
  const best = body.routes?.[0];
  if (body.code !== 'Ok' || !best) {
    throw new Error(`Could not find a road route through these stops (${body.message ?? body.code}).`);
  }
  let total = 0;
  const distanceFromStartM = [0];
  for (const leg of best.legs) {
    total += leg.distance;
    distanceFromStartM.push(Math.round(total));
  }
  return {
    polyline: best.geometry,
    distanceM: Math.round(best.distance),
    distanceFromStartM,
    offRoad: (body.waypoints ?? [])
      .map((w, i) => ({ stopId: stops[i].id, metres: Math.round(w.distance) }))
      .filter((w) => w.metres > OFF_ROAD_M),
  };
}

/** The `routes/{routeId}` document the apps read. */
export function routeDocument(route: RouteDraft, path: RoutePath) {
  const stops = route.stops.map((s, i) => ({
    id: s.id,
    name: s.name.trim(),
    lat: s.lat as number,
    lng: s.lng as number,
    scheduledTime: s.scheduledTime,
    distanceFromStartM: path.distanceFromStartM[i] ?? 0,
  }));
  return {
    name: route.name.trim(),
    city: route.city.trim(),
    active: route.active,
    guestFare: route.guestFare,
    stops,
    stopIds: stops.map((s) => s.id),
    path: path.polyline,
    distanceM: path.distanceM,
  };
}
