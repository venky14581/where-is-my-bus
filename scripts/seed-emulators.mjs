// Creates the demo accounts in the local Firebase emulators. Safe to re-run:
// existing accounts are reset to these values.
//
//   npm run emulators   (in one terminal)
//   npm run seed        (in another)
//
// These are test credentials for the emulators only. Never reuse them on a
// real project.

process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_DATABASE_EMULATOR_HOST ??= '127.0.0.1:9000';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getDatabase } from 'firebase-admin/database';
import { importBaseData } from './base-data.mjs';

const PROJECT_ID = 'demo-whereismybus';
const DRIVER_EMAIL_DOMAIN = 'drivers.whereismybus.invalid'; // AppConfig.driverEmailDomain

if (!PROJECT_ID.startsWith('demo-')) {
  throw new Error('Seeding is only for demo- projects running on the emulators.');
}

const app = initializeApp({ projectId: PROJECT_ID, databaseURL: `https://${PROJECT_ID}-default-rtdb.firebaseio.com` });
const auth = getAuth(app);
const db = getFirestore(app);
const rtdb = getDatabase(app);

export const DEMO_ACCOUNTS = {
  office: {
    uid: 'office-demo',
    email: 'transport.office@cb.amrita.edu',
    password: 'Office#Demo2026',
    profile: { name: 'Transport Office', role: 'office' },
  },
  drivers: [
    { uid: 'driver-DRV001', driverId: 'DRV001', pin: '482913', name: 'Murugan S' },
    { uid: 'driver-DRV002', driverId: 'DRV002', pin: '615204', name: 'Selvam K' },
  ],
  // Exists in Auth but has no profile, to show the "ask the office" screen.
  unassignedDriver: { uid: 'driver-DRV009', driverId: 'DRV009', pin: '900009' },
  student: {
    uid: 'student-demo',
    email: 'cb.en.u4cse00001@cb.students.amrita.edu',
    password: 'Student#Demo2026',
    name: 'Demo Student',
  },
};

async function upsertAuthUser({ uid, email, password, displayName, emailVerified = true }) {
  const fields = { email, password, displayName, emailVerified, disabled: false };
  try {
    await auth.updateUser(uid, fields);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await auth.createUser({ uid, ...fields });
  }
}

const driverEmail = (driverId) => `${driverId.toLowerCase()}@${DRIVER_EMAIL_DOMAIN}`;

async function seed() {
  const { office, drivers, unassignedDriver, student } = DEMO_ACCOUNTS;

  await upsertAuthUser({ uid: office.uid, email: office.email, password: office.password, displayName: office.profile.name });
  await db.doc(`users/${office.uid}`).set({
    ...office.profile,
    email: office.email,
    createdAt: FieldValue.serverTimestamp(),
  });

  for (const driver of drivers) {
    await upsertAuthUser({ uid: driver.uid, email: driverEmail(driver.driverId), password: driver.pin, displayName: driver.name });
    await db.doc(`users/${driver.uid}`).set({
      name: driver.name,
      role: 'driver',
      driverId: driver.driverId,
      // Null so the driver chooses at first login.
      language: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  await upsertAuthUser({ uid: unassignedDriver.uid, email: driverEmail(unassignedDriver.driverId), password: unassignedDriver.pin, displayName: 'Unassigned driver' });
  await db.doc(`users/${unassignedDriver.uid}`).delete();

  await upsertAuthUser({ uid: student.uid, email: student.email, password: student.password, displayName: student.name });
  await db.doc(`users/${student.uid}`).set({
    name: student.name,
    email: student.email,
    role: 'student',
    routeId: null,
    stopId: null,
    passValid: false,
    language: 'en',
    createdAt: FieldValue.serverTimestamp(),
  });

  await rtdb.ref(`officeUids/${office.uid}`).set(true);
  // A fresh start: no bus is running.
  await rtdb.ref('live').remove();
  const counts = await importBaseData(db, rtdb);

  console.log('Seeded the emulators with:');
  console.log(`  office   ${office.email}`);
  for (const d of drivers) console.log(`  driver   ${d.driverId}`);
  console.log(`  driver   ${unassignedDriver.driverId} (no profile)`);
  console.log(`  student  ${student.email}`);
  console.log(`  ${counts.routes} routes and ${counts.buses} buses from data/base-data.json`);
  console.log('Passwords and PINs are in scripts/seed-emulators.mjs.');
}

seed().then(() => process.exit(0)).catch((error) => {
  if (error.code === 'app/network-error' || /ECONNREFUSED/.test(String(error))) {
    console.error('Could not reach the emulators. Start them first with: npm run emulators');
  } else {
    console.error(error);
  }
  process.exitCode = 1;
});
