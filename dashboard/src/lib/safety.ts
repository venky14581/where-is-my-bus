import type { DocumentData, Timestamp } from 'firebase/firestore';

// safetyAlerts/{id}, written by functions/src/safety.ts.

export type AlertType = 'sos' | 'overspeed' | 'offRoute';

export interface SafetyAlert {
  id: string;
  type: AlertType;
  status: 'open' | 'acknowledged';
  tripId: string;
  busNumber: string;
  routeName: string;
  driverName: string;
  fromRole: string;
  fromName: string;
  lat: number | null;
  lng: number | null;
  speedKmh: number | null;
  limitKmh: number | null;
  distanceM: number | null;
  /** When it happened, ms since the epoch; null until the server time arrives. */
  at: number | null;
  acknowledgedAt: number | null;
}

export const ALERT_LABEL: Record<AlertType, string> = {
  sos: 'SOS',
  overspeed: 'Overspeeding',
  offRoute: 'Off the route',
};

const millis = (v: unknown) => (v && typeof (v as Timestamp).toMillis === 'function' ? (v as Timestamp).toMillis() : null);
const num = (v: unknown) => (typeof v === 'number' ? v : null);

export function alertFrom(id: string, d: DocumentData): SafetyAlert | null {
  if (d.type !== 'sos' && d.type !== 'overspeed' && d.type !== 'offRoute') return null;
  const details = (d.details ?? {}) as Record<string, unknown>;
  return {
    id,
    type: d.type,
    status: d.status === 'acknowledged' ? 'acknowledged' : 'open',
    tripId: String(d.tripId ?? ''),
    busNumber: String(d.busNumber ?? ''),
    routeName: String(d.routeName ?? ''),
    driverName: String(d.driverName ?? ''),
    fromRole: String(d.fromRole ?? ''),
    fromName: String(d.fromName ?? ''),
    lat: num(d.lat),
    lng: num(d.lng),
    speedKmh: num(details.speedKmh),
    limitKmh: num(details.limitKmh),
    distanceM: num(details.distanceM),
    at: millis(d.at),
    acknowledgedAt: millis(d.acknowledgedAt),
  };
}

/** One line on what happened, for the office. */
export function describeAlert(a: SafetyAlert): string {
  switch (a.type) {
    case 'sos':
      return `SOS from ${a.fromRole === 'driver' ? 'the driver' : 'a student'}${a.fromName ? ` (${a.fromName})` : ''}`;
    case 'overspeed':
      return a.speedKmh !== null && a.limitKmh !== null ? `${a.speedKmh} km/h where the limit is ${a.limitKmh}` : 'Over the speed limit';
    case 'offRoute':
      return a.distanceM !== null ? `${a.distanceM} m from the route for over a minute` : 'Away from the route';
  }
}

/** Open first, then newest first. */
export function sortAlerts(alerts: SafetyAlert[]): SafetyAlert[] {
  return alerts.slice().sort((a, b) => Number(a.status !== 'open') - Number(b.status !== 'open') || (b.at ?? Infinity) - (a.at ?? Infinity));
}
