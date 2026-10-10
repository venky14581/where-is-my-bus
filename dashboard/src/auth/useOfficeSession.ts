import { useEffect, useState } from 'react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';

export type OfficeSession =
  | { status: 'loading' }
  | { status: 'signedOut'; notice?: 'notOffice' | 'profileError' }
  | { status: 'office'; user: User; name: string };

/**
 * The dashboard is for transport office staff only. Any other signed-in
 * account (a student, a driver) is signed straight back out with a notice.
 * Firestore rules enforce the same split, so this is about a clear message,
 * not security.
 */
export function useOfficeSession(): OfficeSession {
  const [session, setSession] = useState<OfficeSession>({ status: 'loading' });

  useEffect(() => {
    let latestUid: string | null = null;
    return onAuthStateChanged(auth, async (user) => {
      latestUid = user?.uid ?? null;
      if (!user) {
        // Keep a notice from the sign-out we triggered below.
        setSession((prev) => (prev.status === 'signedOut' ? prev : { status: 'signedOut' }));
        return;
      }
      setSession({ status: 'loading' });
      try {
        const snap = await getDoc(doc(db, 'users', user.uid));
        if (latestUid !== user.uid) return;
        if (snap.exists() && snap.data().role === 'office') {
          setSession({ status: 'office', user, name: String(snap.data().name ?? user.email) });
          return;
        }
        setSession({ status: 'signedOut', notice: 'notOffice' });
      } catch {
        setSession({ status: 'signedOut', notice: 'profileError' });
      }
      await signOut(auth);
    });
  }, []);

  return session;
}
