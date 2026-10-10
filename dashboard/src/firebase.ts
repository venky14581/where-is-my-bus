import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';

// Without a .env file this points at the local emulators. For a real project,
// copy .env.example to .env.local and fill in the web app config.
const env = import.meta.env;
const projectId: string = env.VITE_FIREBASE_PROJECT_ID ?? 'demo-whereismybus';

export const app = initializeApp({
  apiKey: env.VITE_FIREBASE_API_KEY ?? 'demo-api-key',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? `${projectId}.firebaseapp.com`,
  projectId,
  appId: env.VITE_FIREBASE_APP_ID ?? '1:000000000000:web:0000000000000000000000',
});

export const auth = getAuth(app);
export const db = getFirestore(app);

// demo- projects only exist on the emulators.
const useEmulators = env.VITE_USE_EMULATORS
  ? env.VITE_USE_EMULATORS === 'true'
  : projectId.startsWith('demo-');

if (useEmulators) {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
}

export const usingEmulators = useEmulators;
