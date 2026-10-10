// What must be true of a project's data before a pilot day: kept free of
// Firebase so it can be tested; scripts/pilot-check.mjs loads the data.
// Each finding is ok, warn (works, but look at it) or fail (fix first).

/** The driver's phone records a stop within this of it (StopDetector). */
export const STOP_RADIUS_M = 80;

export function decodePolyline(encoded) {
  const points = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  while (index < encoded.length) {
    for (const axis of [0, 1]) {
      let result = 0;
      let shift = 0;
      let b;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const delta = result & 1 ? ~(result >> 1) : result >> 1;
      if (axis === 0) lat += delta;
      else lng += delta;
    }
    points.push([lat / 1e5, lng / 1e5]);
  }
  return points;
}

/** Shortest distance in metres from a point to a path, on a local flat projection. */
export function metresFromPath(point, path) {
  const toXY = ([lat, lng]) => [lng * 111320 * Math.cos((point[0] * Math.PI) / 180), lat * 110540];
  const [px, py] = toXY(point);
  let best = Infinity;
  for (let i = 1; i < path.length; i++) {
    const [ax, ay] = toXY(path[i - 1]);
    const [bx, by] = toXY(path[i]);
    const dx = bx - ax;
    const dy = by - ay;
    const t = dx || dy ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))) : 0;
    best = Math.min(best, Math.hypot(px - (ax + t * dx), py - (ay + t * dy)));
  }
  return best;
}

/**
 * @param data {{ routes, buses, users, busDrivers, officeUids, settings, segmentTimes, routeAccess }}
 *   routes, buses, users: [{ id, ...fields }]; the rest maps by id.
 * @returns {{ level: 'ok'|'warn'|'fail', area: string, message: string }[]}
 */
export function pilotChecks(data) {
  const out = [];
  const ok = (area, message) => out.push({ level: 'ok', area, message });
  const warn = (area, message) => out.push({ level: 'warn', area, message });
  const fail = (area, message) => out.push({ level: 'fail', area, message });

  // Routes and stops.
  const active = data.routes.filter((r) => r.active !== false);
  if (active.length === 0) fail('Routes', 'No routes. Import the transport office\'s sheet (npm run import-routes).');
  for (const route of active) {
    const name = `${route.name ?? route.id}`;
    const stops = route.stops ?? [];
    const problems = [];
    if (stops.length < 2) problems.push('fewer than two stops');
    if (stops.at(-1)?.id !== 'campus') problems.push('the last stop is not the campus');
    if (JSON.stringify(route.stopIds) !== JSON.stringify(stops.map((s) => s.id))) problems.push('stopIds do not match the stops (save the route on the dashboard)');
    for (let i = 1; i < stops.length; i++) {
      if (!(stops[i].scheduledTime > stops[i - 1].scheduledTime)) problems.push(`${stops[i].name} is not timed after ${stops[i - 1].name}`);
    }
    if (problems.length) {
      fail('Routes', `${name}: ${problems.join('; ')}.`);
      continue;
    }
    if (!route.path) {
      fail('Routes', `${name}: no road path; arrival times cannot be worked out. Run npm run build-paths, or save the route on the dashboard.`);
      continue;
    }
    const path = decodePolyline(route.path);
    const offRoad = stops
      .map((s) => ({ s, m: metresFromPath([s.lat, s.lng], path) }))
      .filter(({ m }) => m > STOP_RADIUS_M);
    if (offRoad.length) {
      fail('Routes', `${name}: ${offRoad.map(({ s, m }) => `${s.name} ${Math.round(m)} m`).join(', ')} from the road. `
        + `The driver's phone records a stop within ${STOP_RADIUS_M} m, so these would never be recorded. Move each stop onto the road where the bus stops.`);
    } else {
      ok('Routes', `${name}: ${stops.length} stops, ${stops[0].scheduledTime} to ${stops.at(-1).scheduledTime}, all on the road.`);
    }
    const access = data.routeAccess[route.id];
    if (!access) warn('Routes', `${name}: no routeAccess entry; missed-bus help offers no other bus to its riders.`);
    if (typeof route.guestFare !== 'number') warn('Booking', `${name}: no guest fare, so no evening seats can be booked on it.`);
  }

  // Buses and drivers.
  const routeIds = new Set(data.routes.map((r) => r.id));
  const users = new Map(data.users.map((u) => [u.id, u]));
  if (data.buses.length === 0) fail('Buses', 'No buses.');
  for (const bus of data.buses) {
    const label = bus.number ?? bus.id;
    if (!bus.routeId || !routeIds.has(bus.routeId)) {
      warn('Buses', `${label}: no route, so it cannot start a trip.`);
      continue;
    }
    if (!bus.driverId) {
      warn('Buses', `${label}: no driver assigned.`);
      continue;
    }
    const driver = users.get(bus.driverId);
    if (driver?.role !== 'driver') {
      fail('Buses', `${label}: its driver (${bus.driverId}) has no driver profile. Add the driver on the dashboard.`);
    } else if (data.busDrivers[bus.id] !== bus.driverId) {
      fail('Buses', `${label}: the live-position permission (busDrivers) does not match its driver, so their phone cannot send. Reassign the driver on the dashboard.`);
    } else {
      ok('Buses', `${label}: driver ${driver.name ?? ''} (${driver.driverId ?? bus.driverId}).`);
    }
  }

  // Office.
  const office = data.users.filter((u) => u.role === 'office');
  if (office.length === 0) fail('Office', 'No office account.');
  for (const u of office) {
    if (data.officeUids[u.id]) ok('Office', `${u.name ?? u.id} can see live positions.`);
    else fail('Office', `${u.name ?? u.id} is not in officeUids, so the live map stays empty for them.`);
  }

  // Settings.
  if (data.settings.booking) ok('Settings', `Booking opens ${data.settings.booking.opensAt ?? '18:00'}, closes ${data.settings.booking.closesMinutesBefore ?? 30} min before.`);
  else warn('Settings', 'Booking window not set; the defaults (opens 18:00, closes 30 min before) apply.');
  if (data.settings.safety) ok('Settings', `Speed limit ${data.settings.safety.speedLimitKmh} km/h.`);
  else warn('Settings', 'Speed limit not set; 60 km/h applies.');

  // Learned arrival times.
  for (const route of active) {
    const learned = data.segmentTimes[route.id];
    if (!learned) warn('Arrival times', `${route.name ?? route.id}: no learned times; the timetable is used until enough trips are recorded.`);
    else if (learned.source === 'synthetic') warn('Arrival times', `${route.name ?? route.id}: learned times are from synthetic trips. Remove them for the pilot (or retrain on recorded trips) so students see the timetable, not made-up delays.`);
    else ok('Arrival times', `${route.name ?? route.id}: learned from ${learned.trainedOn?.trips ?? '?'} recorded trips.`);
  }
  return out;
}
