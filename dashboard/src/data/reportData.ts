import { useCallback, useEffect, useState } from 'react';
import { collection, getDocs, query, where, type Timestamp } from 'firebase/firestore';
import { db } from '../firebase';
import type { BoardingType, BookingRecord, TripRecord } from '../lib/reports';

export interface ReportData {
  trips: TripRecord[];
  bookings: BookingRecord[];
  loading: boolean;
  error: string | null;
  reload: () => void;
}

const millis = (v: unknown) => (v && typeof (v as Timestamp).toMillis === 'function' ? (v as Timestamp).toMillis() : null);

/** One trip with its stop times and boardings. */
async function loadTrip(id: string, d: Record<string, unknown>): Promise<TripRecord> {
  const [times, boardings] = await Promise.all([
    getDocs(collection(db, `trips/${id}/stopTimes`)),
    getDocs(collection(db, `trips/${id}/boardings`)),
  ]);
  const stopTimes: Record<string, number> = {};
  for (const t of times.docs) {
    const at = millis(t.get('arrivedAt'));
    if (at !== null) stopTimes[t.id] = at;
  }
  return {
    id,
    routeId: String(d.routeId ?? ''),
    busId: String(d.busId ?? ''),
    date: String(d.date ?? ''),
    direction: d.direction === 'fromCampus' ? 'fromCampus' : 'toCampus',
    stopTimes,
    boardings: boardings.docs.map((b) => ({
      type: (['pass', 'alternate', 'guest'].includes(b.get('type')) ? b.get('type') : 'pass') as BoardingType,
      stopId: typeof b.get('stopId') === 'string' ? b.get('stopId') : null,
    })),
  };
}

/**
 * Trips (with stop times and boardings) and bookings between two dates,
 * read once rather than watched: reports are looked at, not followed live.
 */
export function useReportData(from: string, to: string): ReportData {
  const [version, setVersion] = useState(0);
  const reload = useCallback(() => setVersion((v) => v + 1), []);
  const key = `${from}|${to}|${version}`;
  // Loading until the data in hand is for the dates asked for.
  const [state, setState] = useState<{ key: string | null; trips: TripRecord[]; bookings: BookingRecord[]; error: string | null }>(
    { key: null, trips: [], bookings: [], error: null },
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [trips, bookings] = await Promise.all([
        getDocs(query(collection(db, 'trips'), where('date', '>=', from), where('date', '<=', to))),
        getDocs(query(collection(db, 'bookings'), where('date', '>=', from), where('date', '<=', to))),
      ]);
      const records = await Promise.all(trips.docs.map((t) => loadTrip(t.id, t.data())));
      return {
        // Evening trips made ahead for booking but never driven have nothing to show.
        trips: records.filter((t) => Object.keys(t.stopTimes).length > 0 || t.boardings.length > 0),
        bookings: bookings.docs.map((b) => ({
          tripId: String(b.get('tripId') ?? ''),
          routeId: String(b.get('routeId') ?? ''),
          date: String(b.get('date') ?? ''),
          fare: typeof b.get('fare') === 'number' ? b.get('fare') : 0,
          status: String(b.get('status') ?? ''),
        })),
      };
    })().then(
      (data) => !cancelled && setState({ key, ...data, error: null }),
      () => !cancelled && setState((s) => ({ ...s, key, error: "Couldn't load the reports. Check the connection and try again." })),
    );
    return () => {
      cancelled = true;
    };
  }, [from, to, version, key]);

  return { trips: state.trips, bookings: state.bookings, error: state.error, loading: state.key !== key, reload };
}

/** Today on the campus clock, as YYYY-MM-DD. */
export const campusToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
