import { useEffect, useMemo, useState } from 'react';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip, useMap } from 'react-leaflet';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { BusIcon } from '../BusIcon';
import { describeAge } from '../lib/live';
import { decodePolyline } from '../lib/polyline';

interface Shared {
  result: 'ok';
  busNumber: string;
  routeName: string;
  path: string | null;
  stops: { id: string; name: string; lat: number; lng: number }[];
  stopId: string | null;
  bus: { lat: number; lng: number; updatedAt: number | null } | null;
  liveStatus: string | null;
  serverNow: number;
}

type View = { state: 'loading' } | { state: 'ended' } | { state: 'notFound' } | { state: 'error' } | ({ state: 'ok' } & Shared);

/** Polls this often; the bus position itself changes every 3 seconds. */
const POLL_MS = 5000;

/**
 * What a parent sees from a student's "Share my trip" link: that one bus on
 * a map, until the trip ends. No sign-in; the link's token is the
 * permission. Only the bus's location is shown, never the student's.
 */
export function SharePage({ token }: { token: string }) {
  const [view, setView] = useState<View>({ state: 'loading' });
  // A parent is not the transport office.
  useEffect(() => {
    document.title = 'Where Is My Bus · Shared trip';
  }, []);

  useEffect(() => {
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const call = httpsCallable<{ token: string }, { result: string } & Partial<Shared>>(functions, 'viewSharedTrip');
    const poll = async () => {
      try {
        const { data } = await call({ token });
        if (stopped) return;
        if (data.result === 'ok') {
          setView({ state: 'ok', ...(data as Shared) });
          timer = setTimeout(poll, POLL_MS);
        } else {
          setView({ state: data.result === 'ended' ? 'ended' : 'notFound' });
        }
      } catch {
        if (stopped) return;
        setView((v) => (v.state === 'ok' ? v : { state: 'error' }));
        timer = setTimeout(poll, POLL_MS * 2);
      }
    };
    poll();
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [token]);

  return (
    <div className="share-page">
      <header className="share-header">
        <span className="brand-badge"><BusIcon /></span>
        <div>
          <strong>Where Is My Bus</strong>
          <div className="muted">{view.state === 'ok' ? `${view.busNumber} · ${view.routeName}` : 'Shared trip'}</div>
        </div>
      </header>
      {view.state === 'loading' && <div className="centered-small" aria-busy="true"><span className="spinner" /></div>}
      {view.state === 'ended' && <p className="share-note">This trip has ended, so the link no longer shows the bus.</p>}
      {view.state === 'notFound' && <p className="share-note">This link is not valid. Ask for a new one.</p>}
      {view.state === 'error' && <p className="share-note">Can't reach the server. Trying again…</p>}
      {view.state === 'ok' && <SharedMap view={view} />}
    </div>
  );
}

function SharedMap({ view }: { view: Shared }) {
  const path = useMemo(() => (view.path ? decodePolyline(view.path) : view.stops.map((s) => [s.lat, s.lng] as [number, number])), [view.path, view.stops]);
  const home = view.stops.find((s) => s.id === view.stopId);
  const age = view.bus?.updatedAt ? view.serverNow - view.bus.updatedAt : null;
  const fresh = age !== null && age < 30_000 && view.liveStatus === 'running';
  return (
    <>
      <p className="share-note" role="status">
        {view.bus === null ? 'Waiting for the bus position…'
          : fresh ? `Live · updated ${describeAge(age!)}`
            : `Last seen ${describeAge(age ?? 0)}${view.liveStatus === 'offline' ? ' (the driver\'s phone is offline)' : ''}`}
        {home && ` · Your student's stop: ${home.name}`}
      </p>
      <div className="share-map">
        <MapContainer bounds={path.length > 1 ? path : undefined} center={path[0]} zoom={12} className="map">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' />
          <Polyline positions={path} pathOptions={{ color: '#8c1d40', weight: 4, opacity: 0.5 }} />
          {view.stops.map((s) => (
            <CircleMarker key={s.id} center={[s.lat, s.lng]} radius={s.id === view.stopId ? 9 : 5}
              pathOptions={{ color: '#fff', weight: 2, fillColor: s.id === view.stopId ? '#c47f00' : '#8c1d40', fillOpacity: 1 }}>
              <Tooltip>{s.name}</Tooltip>
            </CircleMarker>
          ))}
          {view.bus && (
            <>
              <CircleMarker center={[view.bus.lat, view.bus.lng]} radius={12}
                pathOptions={{ color: '#fff', weight: 3, fillColor: fresh ? '#1b7f3b' : '#8a8a8a', fillOpacity: 1 }}>
                <Tooltip permanent direction="top" offset={[0, -12]}>{view.busNumber}</Tooltip>
              </CircleMarker>
              <Follow lat={view.bus.lat} lng={view.bus.lng} />
            </>
          )}
        </MapContainer>
      </div>
    </>
  );
}

/** Keeps the bus in view as it moves. */
function Follow({ lat, lng }: { lat: number; lng: number }) {
  const map = useMap();
  useEffect(() => {
    if (!map.getBounds().pad(-0.2).contains([lat, lng])) map.panTo([lat, lng]);
  }, [lat, lng, map]);
  return null;
}
