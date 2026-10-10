// Builds the Cloud Functions, then starts the Firebase emulators.
//
//   npm run emulators
//
// A cold first start can take the functions longer to load than the
// emulator's default 10 seconds (on Windows, mostly antivirus scanning
// node_modules), which leaves them unloaded. Allow a minute instead.

import { spawn } from 'node:child_process';

function run(command, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, { stdio: 'inherit', shell: true, env: { ...process.env, ...env } });
    child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${command} exited with ${code}`))));
  });
}

await run('npm --prefix functions run build');
await run('firebase emulators:start --project demo-whereismybus', { FUNCTIONS_DISCOVERY_TIMEOUT: '60' });
