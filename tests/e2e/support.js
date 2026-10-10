// Shared setup for the end-to-end tests. They run against the full emulator
// suite (auth, Firestore, Realtime Database and the built Cloud Functions):
//
//   npm run test:e2e          starts the emulators, runs everything, stops them
//   npx vitest run tests/e2e  against emulators already started with npm run emulators
//
// People act through the Firebase client SDK, as the app does, so the
// security rules apply to everything they do. Setup and checks use the Admin
// SDK, which bypasses the rules.

process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_DATABASE_EMULATOR_HOST ??= '127.0.0.1:9000';
process.env.GCLOUD_PROJECT ??= 'demo-whereismybus';

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

import { deleteApp, initializeApp, setLogLevel } from 'firebase/app';
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { connectDatabaseEmulator, getDatabase } from 'firebase/database';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';
import { getApps, initializeApp as initializeAdmin } from 'firebase-admin/app';
import { getAuth as getAdminAuth } from 'firebase-admin/auth';
import { getDatabase as getAdminDatabase } from 'firebase-admin/database';
import { getFirestore as getAdminFirestore } from 'firebase-admin/firestore';

// Refusals are expected in these tests; the SDK would log each one.
setLogLevel('silent');

export const PROJECT = 'demo-whereismybus';
// The instance database.rules.json applies to (see CLAUDE.md).
const DATABASE_URL = `https://${PROJECT}-default-rtdb.firebaseio.com`;

const adminApp = getApps().find((a) => a.name === 'e2e-admin')
  ?? initializeAdmin({ projectId: PROJECT, databaseURL: DATABASE_URL }, 'e2e-admin');
export const admin = {
  db: getAdminFirestore(adminApp),
  rtdb: getAdminDatabase(adminApp),
  auth: getAdminAuth(adminApp),
};

/** The demo accounts made by scripts/seed-emulators.mjs. */
export const SEEDED = {
  office: { email: 'transport.office@cb.amrita.edu', password: 'Office#Demo2026' },
  student: { uid: 'student-demo', email: 'cb.en.u4cse00001@cb.students.amrita.edu', password: 'Student#Demo2026' },
  drv001: { uid: 'driver-DRV001', email: 'drv001@drivers.whereismybus.invalid', password: '482913' },
  drv002: { uid: 'driver-DRV002', email: 'drv002@drivers.whereismybus.invalid', password: '615204' },
  drv009: { uid: 'driver-DRV009', email: 'drv009@drivers.whereismybus.invalid', password: '900009' },
};

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Polls [check] until it returns something truthy; for work done by triggers.
 * The emulator starts a worker for each function the first time it fires,
 * which on Windows can take over 20 seconds, hence the long default.
 */
export async function waitFor(check, { timeout = 45_000, interval = 250, what = 'condition' } = {}) {
  const end = Date.now() + timeout;
  let last;
  while (Date.now() < end) {
    try {
      last = await check();
      if (last) return last;
    } catch (e) {
      last = e;
    }
    await sleep(interval);
  }
  throw new Error(`Timed out waiting for ${what}: ${last instanceof Error ? last.message : JSON.stringify(last)}`);
}

/** Empties every emulator, then runs the normal seed script. */
export async function resetAndSeed() {
  const ok = (r) => { if (!r.ok) throw new Error(`${r.url}: ${r.status}`); };
  ok(await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' }));
  ok(await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' }));
  await admin.rtdb.ref('/').remove();
  await promisify(execFile)(process.execPath, ['scripts/seed-emulators.mjs'], { env: process.env });
  // The seed writes buses; let the mirror trigger settle before tests run.
  await waitFor(async () => (await admin.rtdb.ref('busDrivers/bus-01').get()).val() === SEEDED.drv001.uid, { what: 'busDrivers mirror' });
}

let appCount = 0;
const open = [];

/** A separate Firebase app per person, pointed at the emulators. */
function clientApp() {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'demo-key', databaseURL: DATABASE_URL }, `e2e-${appCount++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const rtdb = getDatabase(app);
  connectDatabaseEmulator(rtdb, '127.0.0.1', 9000);
  const functions = getFunctions(app, 'asia-south1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  open.push(app);
  return { app, auth, db, rtdb, functions };
}

function person(client, user) {
  return {
    ...client,
    uid: user.uid,
    /** Calls a callable function and returns its data. */
    call: async (name, data) => (await httpsCallable(client.functions, name)(data)).data,
  };
}

/** Someone with no account, such as a parent opening a shared trip link. */
export function anonymous() {
  const client = clientApp();
  return { ...client, call: async (name, data) => (await httpsCallable(client.functions, name)(data)).data };
}

export async function signIn({ email, password }) {
  const client = clientApp();
  const { user } = await signInWithEmailAndPassword(client.auth, email, password);
  return person(client, user);
}

export async function signUp({ email, password }) {
  const client = clientApp();
  const { user } = await createUserWithEmailAndPassword(client.auth, email, password);
  return person(client, user);
}

/** A verified student with a profile written by the office (Admin SDK). */
export async function makeStudent(uid, profile = {}) {
  const email = `cb.en.u4cse${String(10000 + Math.floor(Math.random() * 89999))}@cb.students.amrita.edu`;
  await admin.auth.createUser({ uid, email, password: 'Student#Demo2026', emailVerified: true });
  await admin.db.doc(`users/${uid}`).set({
    name: `Student ${uid}`, email, role: 'student', routeId: null, stopId: null, passValid: false, language: 'en', ...profile,
  });
  return signIn({ email, password: 'Student#Demo2026' });
}

export async function closeAll() {
  await Promise.all(open.splice(0).map((app) => deleteApp(app)));
}

/** YYYY-MM-DD on the campus clock (India, no daylight saving). */
export function campusDate(at = new Date()) {
  return new Date(at.getTime() + 5.5 * 3600_000).toISOString().slice(0, 10);
}

export function addDays(date, days) {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** A campus-clock time on [date] as a Date. */
export const campusTime = (date, hhmm) => new Date(`${date}T${hhmm}:00+05:30`);

/** A pass valid for the next two months. */
export const passUntil = () => addDays(campusDate(), 60);

/** The rejection code of a failed call, e.g. 'permission-denied' or 'functions/not-found'. */
export async function errorCode(promise) {
  try {
    await promise;
  } catch (e) {
    return e.code ?? String(e);
  }
  return 'no error';
}
