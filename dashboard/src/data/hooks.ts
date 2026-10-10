import { useEffect, useState } from 'react';
import { onValue, ref } from 'firebase/database';
import { onSnapshot, type DocumentData, type DocumentReference, type Query } from 'firebase/firestore';
import { rtdb } from '../firebase';

export interface Live<T> {
  data: T;
  loading: boolean;
  error: Error | null;
}

/**
 * Subscribes to a Firestore query while the component is mounted. [key] says
 * when the query has changed, since query objects are rebuilt every render.
 */
export function useQuery<T>(query: Query<DocumentData> | null, map: (id: string, data: DocumentData) => T | null, key: string): Live<T[]> {
  const [state, setState] = useState<Live<T[]>>({ data: [], loading: query !== null, error: null });
  useEffect(() => {
    if (!query) return;
    return onSnapshot(
      query,
      (snap) => setState({
        data: snap.docs.map((d) => map(d.id, d.data())).filter((x): x is T => x !== null),
        loading: false,
        error: null,
      }),
      (error) => setState((s) => ({ ...s, loading: false, error })),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return state;
}

export function useDocument<T>(docRef: DocumentReference | null, map: (data: DocumentData | undefined) => T, key: string): Live<T> {
  const [state, setState] = useState<Live<T>>({ data: map(undefined), loading: docRef !== null, error: null });
  useEffect(() => {
    if (!docRef) return;
    return onSnapshot(
      docRef,
      (snap) => setState({ data: map(snap.data()), loading: false, error: null }),
      (error) => setState((s) => ({ ...s, loading: false, error })),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return state;
}

/** A Realtime Database value, e.g. all of `live`. */
export function useRtdbValue<T>(path: string, map: (value: unknown) => T): T {
  const [value, setValue] = useState<T>(() => map(null));
  useEffect(() => onValue(ref(rtdb, path), (snap) => setValue(map(snap.val()))), [path]); // eslint-disable-line react-hooks/exhaustive-deps
  return value;
}

/**
 * The server's current time, ticking every second, so "updated 20 s ago" is
 * right even if this computer's clock is off.
 */
export function useServerNow(): number {
  const offset = useRtdbValue('.info/serverTimeOffset', (v) => (typeof v === 'number' ? v : 0));
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  return now + offset;
}
