// Shared setup, imported first by every function file.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';

export const app = initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

export const db = getFirestore(app);
