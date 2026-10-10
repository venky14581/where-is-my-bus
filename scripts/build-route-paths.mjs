// Fetches the road path for every route in data/base-data.json from OSRM and
// writes data/route-paths.json. Re-run after changing stops or their order.
//
//   npm run build-paths
//
// Only stop coordinates are sent. The public OSRM demo server is fine for a
// handful of routes; switch OSRM_URL to a self-hosted server for heavy use.

import { readFile, writeFile } from 'node:fs/promises';

const OSRM_URL = process.env.OSRM_URL ?? 'https://router.project-osrm.org';
const base = JSON.parse(await readFile(new URL('../data/base-data.json', import.meta.url), 'utf8'));

const paths = {};
for (const route of base.routes) {
  const coords = route.stops.map((s) => `${s.lng},${s.lat}`).join(';');
  const url = `${OSRM_URL}/route/v1/driving/${coords}?overview=full&geometries=polyline`;
  const res = await fetch(url);
  const body = await res.json();
  if (!res.ok || body.code !== 'Ok') {
    throw new Error(`OSRM failed for ${route.id}: ${body.code ?? res.status} ${body.message ?? ''}`);
  }
  const [best] = body.routes;
  // Distance along the road from the first stop to each stop. Module 5 uses
  // it for the first arrival-time estimate.
  let total = 0;
  const distanceFromStartM = [0];
  for (const leg of best.legs) {
    total += leg.distance;
    distanceFromStartM.push(Math.round(total));
  }
  paths[route.id] = {
    polyline: best.geometry, // Google encoded polyline, precision 5
    distanceM: Math.round(best.distance),
    durationS: Math.round(best.duration),
    distanceFromStartM,
  };
  console.log(`${route.id}: ${(best.distance / 1000).toFixed(1)} km, ${route.stops.length} stops`);
  // The phone records a stop when the bus comes within 80 m of it, so a stop
  // placed away from the road is never recorded.
  body.waypoints.forEach((waypoint, i) => {
    if (waypoint.distance > 50) {
      console.warn(`  ! ${route.stops[i].id} is ${Math.round(waypoint.distance)} m from the road. Move it to the roadside.`);
    }
  });
  await new Promise((r) => setTimeout(r, 1100)); // demo server allows ~1 request/s
}

await writeFile(new URL('../data/route-paths.json', import.meta.url), `${JSON.stringify(paths, null, 2)}\n`);
console.log('Wrote data/route-paths.json');
