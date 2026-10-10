// Checks the transport office's route and bus sheets and, with --write, puts
// them in data/base-data.json. Then build the road paths and load them.
//
//   npm run import-routes -- --stops stops.csv --buses buses.csv
//   npm run import-routes -- --stops stops.csv --buses buses.csv --write
//   npm run build-paths
//   npm run seed                (emulators)
//
// Fill in data/templates/stops-template.csv and buses-template.csv
// (spreadsheet → Save as CSV). Which routes may carry riders from which
// (routeAccess) stays as it is in base-data.json, or is set on the dashboard.

import { readFile, writeFile } from 'node:fs/promises';
import { busesFromCsv, routesFromCsv } from './routes-csv.mjs';

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const stopsFile = option('stops');
const busesFile = option('buses');
if (!stopsFile) {
  console.error('Usage: npm run import-routes -- --stops stops.csv [--buses buses.csv] [--write]');
  process.exit(2);
}

const { routes, errors } = routesFromCsv(await readFile(stopsFile, 'utf8'));
const busResult = busesFile ? busesFromCsv(await readFile(busesFile, 'utf8'), routes.map((r) => r.id)) : null;
errors.push(...(busResult?.errors ?? []));

for (const route of routes) {
  console.log(`${route.id}: ${route.name} (${route.city}), ${route.stops.length} stops, ${route.stops[0]?.scheduledTime} to ${route.stops.at(-1)?.scheduledTime}`);
}
if (busResult) console.log(`${busResult.buses.length} buses`);

if (errors.length) {
  console.error(`\n${errors.length} problem${errors.length > 1 ? 's' : ''} to fix in the sheet${errors.length > 1 ? 's' : ''}:`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}

if (!args.includes('--write')) {
  console.log('\nNo problems found. Run again with --write to put these in data/base-data.json.');
  process.exit(0);
}

const path = new URL('../data/base-data.json', import.meta.url);
const base = JSON.parse(await readFile(path, 'utf8'));
const ids = new Set(routes.map((r) => r.id));
const access = (base.routeAccess ?? [])
  .filter((a) => ids.has(a.routeId))
  .map((a) => ({ ...a, acceptsFrom: a.acceptsFrom.filter((id) => ids.has(id)) }));
for (const id of ids) if (!access.some((a) => a.routeId === id)) access.push({ routeId: id, acceptsFrom: [] });

const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
const next = {
  _note: `From the transport office's route sheet, imported ${today}. After editing stops, run \`npm run build-paths\`, then \`npm run seed\`.`,
  routes,
  buses: busResult?.buses ?? base.buses.filter((b) => ids.has(b.routeId)),
  routeAccess: access,
};
await writeFile(path, `${JSON.stringify(next, null, 2)}\n`);
console.log('\nWrote data/base-data.json. Next: npm run build-paths, then npm run seed.');
