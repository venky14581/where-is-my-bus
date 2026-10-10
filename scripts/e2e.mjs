// End-to-end tests for every module against the full emulator suite.
//
//   npm run test:e2e
//
// If the emulators are already running (npm run emulators), the tests use
// them; otherwise this builds the functions, starts the emulators, runs the
// tests and stops them. The tests empty and re-seed the emulators.

import { spawn } from 'node:child_process';

function run(command, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, { stdio: 'inherit', shell: true, env: { ...process.env, ...env } });
    child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${command} exited with ${code}`))));
  });
}

async function emulatorsRunning() {
  try {
    await fetch('http://127.0.0.1:4400/emulators');
    return true;
  } catch {
    return false;
  }
}

const vitest = 'npx vitest run tests/e2e --no-file-parallelism --test-timeout=60000 --hook-timeout=120000';

try {
  if (await emulatorsRunning()) {
    console.log('Using the emulators already running.');
    await run(vitest);
  } else {
    await run('npm --prefix functions run build');
    // A cold start can take the functions longer than the default 10 s to load.
    await run(`firebase emulators:exec --project demo-whereismybus "${vitest}"`, { FUNCTIONS_DISCOVERY_TIMEOUT: '60' });
  }
} catch (e) {
  console.error(e.message);
  process.exitCode = 1;
}
