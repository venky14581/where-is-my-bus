import { useEffect, useMemo, useState } from 'react';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip } from 'react-leaflet';
import { collection, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { useBuses, useRoutes, type Route } from '../data/baseData';
import { useQuery } from '../data/hooks';
import { campusToday, useReportData } from '../data/reportData';
import { alongAt, minutesLateAtCampus, pointAlong, type TripRecord } from '../lib/reports';
import { decodePolyline } from '../lib/polyline';
import { ALERT_LABEL, type SafetyAlert, alertFrom } from '../lib/safety';

const clock = (ms: number) => new Date(ms).toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' });

/**
 * Any past trip on the map: the stop times recorded, and a replay. Only
 * stop times are kept, so the bus between stops is an estimate.
 */
export function TripHistoryPage() {
  const [date, setDate] = useState(campusToday);
  const data = useReportData(date, date);
  const routes = useRoutes().data;
  const buses = useBuses().data;
  const [tripId, setTripId] = useState<string | null>(null);
  const trips = useMemo(() => data.trips.slice().sort((a, b) => a.id.localeCompare(b.id)), [data.trips]);
  const trip = trips.find((t) => t.id === tripId) ?? trips[0];
  const route = routes.find((r) => r.id === trip?.routeId);

  return (
    <section className="page">
      <h2>Trip history</h2>
      <div className="toolbar">
        <label className="field inline"><span>Date</span>
          <input type="date" value={date} max={campusToday()} onChange={(e) => { setDate(e.target.value); setTripId(null); }} />
        </label>
        <label className="field inline"><span>Trip</span>
          <select value={trip?.id ?? ''} onChange={(e) => setTripId(e.target.value)} disabled={trips.length === 0}>
            {trips.map((t) => (
              <option key={t.id} value={t.id}>
                {buses.find((b) => b.id === t.busId)?.number ?? t.busId} · {routes.find((r) => r.id === t.routeId)?.name ?? t.routeId} · {t.direction === 'toCampus' ? 'morning' : 'evening'}
              </option>
            ))}
          </select>
        </label>
      </div>
      {data.loading ? <div className="centered-small" aria-busy="true"><span className="spinner" /></div>
        : !trip || !route ? <p className="muted">No trips recorded on this day.</p>
          : <TripReplay key={trip.id} trip={trip} route={route} />}
    </section>
  );
}

function TripReplay({ trip, route }: { trip: TripRecord; route: Route }) {
  const placed = route.stops.filter((s): s is typeof s & { lat: number; lng: number } => s.lat !== null && s.lng !== null);
  const path = useMemo(
    () => (route.path ? decodePolyline(route.path) : placed.map((s) => [s.lat, s.lng] as [number, number])),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [route],
  );
  const times = Object.values(trip.stopTimes).sort((a, b) => a - b);
  const [start, end] = [times[0], times.at(-1)];
  const [at, setAt] = useState(start ?? 0);
  const [playing, setPlaying] = useState(false);
  const alerts = useQuery<SafetyAlert>(query(collection(db, 'safetyAlerts'), where('tripId', '==', trip.id)), alertFrom, `alerts-${trip.id}`).data;

  useEffect(() => {
    if (!playing || start === undefined || end === undefined) return;
    // The whole trip in about 30 seconds.
    const step = Math.max(1000, (end - start) / 150);
    const timer = setInterval(() => setAt((t) => {
      if (t + step >= end) {
        setPlaying(false);
        return end;
      }
      return t + step;
    }), 200);
    return () => clearInterval(timer);
  }, [playing, start, end]);

  const along = alongAt(trip, route, at);
  const bus = along === null ? null : pointAlong(path, along);
  const late = minutesLateAtCampus(trip, route);
  const ordered = trip.direction === 'toCampus' ? route.stops : [...route.stops].reverse();

  return (
    <div className="map-and-list">
      <div className="map-frame">
        <MapContainer bounds={path.length > 1 ? path : undefined} center={path[0]} zoom={12} scrollWheelZoom className="map">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' />
          <Polyline positions={path} pathOptions={{ color: '#8c1d40', weight: 4, opacity: 0.5 }} />
          {placed.map((s) => (
            <CircleMarker key={s.id} center={[s.lat, s.lng]} radius={6}
              pathOptions={{ color: '#fff', weight: 2, fillColor: trip.stopTimes[s.id] ? '#1b7f3b' : '#8a8a8a', fillOpacity: 1 }}>
              <Tooltip>{s.name}: {trip.stopTimes[s.id] ? clock(trip.stopTimes[s.id]) : 'not recorded'}</Tooltip>
            </CircleMarker>
          ))}
          {alerts.filter((a) => a.lat !== null && a.lng !== null).map((a) => (
            <CircleMarker key={a.id} center={[a.lat!, a.lng!]} radius={9} pathOptions={{ color: '#fff', weight: 2, fillColor: '#c62828', fillOpacity: 1 }}>
              <Tooltip>{ALERT_LABEL[a.type]}{a.at ? ` at ${clock(a.at)}` : ''}</Tooltip>
            </CircleMarker>
          ))}
          {bus && (
            <CircleMarker center={bus} radius={11} pathOptions={{ color: '#fff', weight: 3, fillColor: '#2f6f9f', fillOpacity: 1 }}>
              <Tooltip permanent direction="top" offset={[0, -10]}>{clock(at)}</Tooltip>
            </CircleMarker>
          )}
        </MapContainer>
      </div>
      <div>
        {start !== undefined && end !== undefined && end > start && (
          <div className="panel replay">
            <button className="primary" onClick={() => { if (at >= end) setAt(start); setPlaying(!playing); }}>{playing ? 'Pause' : 'Replay'}</button>
            <input type="range" aria-label="Time in the trip" min={start} max={end} step={1000} value={at}
              onChange={(e) => { setPlaying(false); setAt(Number(e.target.value)); }} />
            <span>{clock(at)}</span>
          </div>
        )}
        <p className="muted">Stop times are recorded by the driver's phone; the bus between stops is estimated from them.{late !== null && ` Campus: ${late > 0 ? `${Math.round(late)} min late` : 'on time'}.`}</p>
        <table className="table">
          <thead><tr><th>Stop</th><th>Scheduled</th><th>Recorded</th></tr></thead>
          <tbody>
            {ordered.map((s) => (
              <tr key={s.id}>
                <td>{s.name}</td>
                <td>{trip.direction === 'toCampus' ? s.scheduledTime : '—'}</td>
                <td>{trip.stopTimes[s.id] ? clock(trip.stopTimes[s.id]) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="muted">{trip.boardings.length} boardings. {alerts.length ? `${alerts.length} safety alert${alerts.length > 1 ? 's' : ''} on this trip.` : 'No safety alerts on this trip.'}</p>
      </div>
    </div>
  );
}
