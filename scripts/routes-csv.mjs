// Reads the transport office's route spreadsheet (saved as CSV) into the
// shape of data/base-data.json, and says what is wrong with it. Kept free of
// files and Firebase so it can be tested; scripts/import-routes.mjs runs it.
//
// stops.csv, one row per stop, stops of a route in travel order to campus:
//   route_id,route_name,city,stop_order,stop_id,stop_name,lat,lng,scheduled_time
// buses.csv, one row per bus:
//   bus_id,number,capacity,route_id,driver_id
//
// Templates: data/templates/.

/** Same place as CAMPUS in the dashboard and the seed data. */
export const CAMPUS = { lat: 10.9027, lng: 76.9006 };
/** The last stop must be this close to the campus to count as it. */
const CAMPUS_RADIUS_M = 400;
/** Stops further than this from the campus are almost certainly typing mistakes. */
const MAX_FROM_CAMPUS_KM = 150;

/** Splits CSV text into rows of cells. Handles quoted cells with commas and quotes. */
export function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (c === '"') {
        quoted = false;
      } else {
        cell += c;
      }
    } else if (c === '"') {
      quoted = true;
    } else if (c === ',') {
      row.push(cell);
      cell = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += c;
    }
  }
  if (cell !== '' || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

/** Rows as objects keyed by the header row, with the spreadsheet's row number for messages. */
function records(text, required) {
  const [header, ...rows] = parseCsv(text.replace(/^﻿/, ''));
  const names = (header ?? []).map((h) => h.trim().toLowerCase());
  const missing = required.filter((r) => !names.includes(r));
  if (missing.length) return { rows: [], errors: [`Missing column${missing.length > 1 ? 's' : ''}: ${missing.join(', ')}`] };
  return {
    rows: rows.map((cells, i) => ({ line: i + 2, ...Object.fromEntries(names.map((n, j) => [n, (cells[j] ?? '').trim()])) })),
    errors: [],
  };
}

export function slug(name) {
  return name.toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/[\s_]+/g, '-').replace(/-+/g, '-');
}

export function kmBetween(a, b) {
  const rad = Math.PI / 180;
  const h = Math.sin(((b.lat - a.lat) * rad) / 2) ** 2
    + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(((b.lng - a.lng) * rad) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

const HHMM = /^([01]?\d|2[0-3]):[0-5]\d$/;

/**
 * Routes from stops.csv. Returns the routes and every problem found, each
 * naming the spreadsheet row, so the office can fix them in one go.
 */
export function routesFromCsv(text) {
  const { rows, errors } = records(text, ['route_id', 'route_name', 'city', 'stop_order', 'stop_name', 'lat', 'lng', 'scheduled_time']);
  const byRoute = new Map();
  for (const r of rows) {
    if (!r.route_id) {
      errors.push(`Row ${r.line}: no route_id.`);
      continue;
    }
    if (!byRoute.has(r.route_id)) byRoute.set(r.route_id, []);
    byRoute.get(r.route_id).push(r);
  }

  const routes = [];
  for (const [routeId, stopRows] of byRoute) {
    if (!/^[a-z0-9-]{2,40}$/.test(routeId)) errors.push(`Route ${routeId}: route_id may use only small letters, digits and dashes.`);
    const named = new Set(stopRows.map((r) => r.route_name));
    if (named.size > 1) errors.push(`Route ${routeId}: more than one route_name (${[...named].join(' / ')}).`);
    stopRows.sort((a, b) => Number(a.stop_order) - Number(b.stop_order));
    const stops = [];
    const seen = new Set();
    stopRows.forEach((r, i) => {
      const where = `Row ${r.line} (${routeId}, ${r.stop_name || 'no name'})`;
      if (Number(r.stop_order) !== i + 1) errors.push(`${where}: stop_order should be ${i + 1}; number the stops 1, 2, 3… in travel order.`);
      if (!r.stop_name) errors.push(`${where}: no stop_name.`);
      const lat = Number(r.lat);
      const lng = Number(r.lng);
      if (!r.lat || !r.lng || !Number.isFinite(lat) || !Number.isFinite(lng)) {
        errors.push(`${where}: lat and lng must be numbers, e.g. 10.9886 and 76.9620.`);
      } else if (kmBetween({ lat, lng }, CAMPUS) > MAX_FROM_CAMPUS_KM) {
        errors.push(`${where}: ${Math.round(kmBetween({ lat, lng }, CAMPUS))} km from campus. Are lat and lng swapped or mistyped?`);
      }
      if (!HHMM.test(r.scheduled_time)) errors.push(`${where}: scheduled_time must be like 07:15 (24-hour).`);
      const last = i === stopRows.length - 1;
      let id = r.stop_id ? r.stop_id : slug(r.stop_name);
      if (last) {
        if (Number.isFinite(lat) && Number.isFinite(lng) && kmBetween({ lat, lng }, CAMPUS) * 1000 > CAMPUS_RADIUS_M) {
          errors.push(`${where}: the last stop of every route must be the campus.`);
        }
        id = 'campus';
      }
      if (!/^[a-z0-9-]{1,60}$/.test(id)) errors.push(`${where}: stop_id "${id}" may use only small letters, digits and dashes.`);
      if (seen.has(id)) errors.push(`${where}: stop_id "${id}" is used twice on this route.`);
      seen.add(id);
      stops.push({ id, name: r.stop_name, lat, lng, scheduledTime: r.scheduled_time.padStart(5, '0') });
    });
    for (let i = 1; i < stops.length; i++) {
      if (HHMM.test(stops[i].scheduledTime) && HHMM.test(stops[i - 1].scheduledTime) && stops[i].scheduledTime <= stops[i - 1].scheduledTime) {
        errors.push(`Route ${routeId}: ${stops[i].name} (${stops[i].scheduledTime}) is not after ${stops[i - 1].name} (${stops[i - 1].scheduledTime}).`);
      }
    }
    if (stops.length < 2) errors.push(`Route ${routeId}: needs at least two stops, the last being the campus.`);
    routes.push({ id: routeId, name: stopRows[0].route_name, city: stopRows[0].city, stops });
  }
  return { routes, errors };
}

/** Buses from buses.csv, checked against the routes. */
export function busesFromCsv(text, routeIds) {
  const { rows, errors } = records(text, ['bus_id', 'number', 'capacity', 'route_id', 'driver_id']);
  const buses = [];
  const seen = new Set();
  for (const r of rows) {
    const where = `Row ${r.line} (${r.bus_id || 'no bus_id'})`;
    if (!/^[a-z0-9-]{2,40}$/.test(r.bus_id)) errors.push(`${where}: bus_id may use only small letters, digits and dashes.`);
    if (seen.has(r.bus_id)) errors.push(`${where}: bus_id used twice.`);
    seen.add(r.bus_id);
    const capacity = Number(r.capacity);
    if (!Number.isInteger(capacity) || capacity < 1 || capacity > 120) errors.push(`${where}: capacity must be a whole number of seats, 1 to 120.`);
    if (!r.number) errors.push(`${where}: no number (the registration, e.g. TN 37 AB 1201).`);
    if (r.route_id && !routeIds.includes(r.route_id)) errors.push(`${where}: route ${r.route_id} is not in the stops sheet.`);
    if (r.driver_id && !/^[A-Za-z0-9-]{3,16}$/.test(r.driver_id)) errors.push(`${where}: driver_id like DRV001.`);
    buses.push({
      id: r.bus_id,
      number: r.number,
      capacity,
      routeId: r.route_id || null,
      driver: r.driver_id ? r.driver_id.toUpperCase() : null,
    });
  }
  return { buses, errors };
}
