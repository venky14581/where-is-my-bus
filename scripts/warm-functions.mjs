// Wakes every callable Cloud Function in the local emulators once.
//
//   npm run warm-functions        (also run at the end of `npm run seed`)
//
// On the emulators each function starts its own worker the first time it is
// called, which took over 20 s per function on the project laptop. Without
// this, the first pass scan, SOS or trip link of a demo waits that long.
// Each call is unauthenticated, so it is refused at once and changes nothing.

const PROJECT_ID = 'demo-whereismybus';
const REGION = 'asia-south1';
const HOST = process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';

// Keep in step with the onCall exports in functions/src/.
export const CALLABLES = [
  'scanPass',
  'sendSos',
  'shareTrip',
  'viewSharedTrip',
  'holdSeat',
  'cancelHold',
  'bookSeat',
  'payBooking',
  'cancelBooking',
  'setNotRiding',
  'createDriver',
  'setDriverPin',
];

export async function warmFunctions({ log = console.log } = {}) {
  const started = Date.now();
  const results = await Promise.all(CALLABLES.map(async (name) => {
    const t = Date.now();
    try {
      const response = await fetch(`http://${HOST}/${PROJECT_ID}/${REGION}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: {} }),
        signal: AbortSignal.timeout(120_000),
      });
      return { name, ok: response.status < 500, ms: Date.now() - t };
    } catch {
      return { name, ok: false, ms: Date.now() - t };
    }
  }));
  const failed = results.filter((r) => !r.ok).map((r) => r.name);
  log(`Functions warmed in ${Math.round((Date.now() - started) / 1000)} s${failed.length ? `; no answer from ${failed.join(', ')}` : ''}.`);
  return results;
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/').replace(/^\//, '')}`) {
  await warmFunctions();
}
