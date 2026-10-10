import { collection, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { useQuery } from './hooks';
import type { StopDraft } from '../lib/routeEdit';

export interface Route {
  id: string;
  name: string;
  city: string;
  active: boolean;
  guestFare: number | null;
  stops: (StopDraft & { distanceFromStartM?: number })[];
  path: string | null;
}

export interface Bus {
  id: string;
  number: string;
  capacity: number;
  routeId: string | null;
  /** The driver's uid. */
  driverId: string | null;
}

export interface Driver {
  uid: string;
  name: string;
  /** The ID they sign in with, e.g. DRV001. */
  driverId: string;
}

export function useRoutes() {
  return useQuery<Route>(collection(db, 'routes'), (id, d) => ({
    id,
    name: String(d.name ?? id),
    city: String(d.city ?? ''),
    active: d.active !== false,
    guestFare: typeof d.guestFare === 'number' ? d.guestFare : null,
    stops: Array.isArray(d.stops) ? d.stops : [],
    path: typeof d.path === 'string' ? d.path : null,
  }), 'routes');
}

export function useBuses() {
  return useQuery<Bus>(collection(db, 'buses'), (id, d) => ({
    id,
    number: String(d.number ?? id),
    capacity: typeof d.capacity === 'number' ? d.capacity : 0,
    routeId: typeof d.routeId === 'string' ? d.routeId : null,
    driverId: typeof d.driverId === 'string' ? d.driverId : null,
  }), 'buses');
}

export function useDrivers() {
  return useQuery<Driver>(query(collection(db, 'users'), where('role', '==', 'driver')), (uid, d) => ({
    uid,
    name: String(d.name ?? ''),
    driverId: String(d.driverId ?? ''),
  }), 'drivers');
}

export const byName = <T extends { name: string }>(a: T, b: T) => a.name.localeCompare(b.name);
