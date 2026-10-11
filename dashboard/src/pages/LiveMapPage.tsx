import { useEffect, useMemo, useState } from 'react';
import L from 'leaflet';
import { MapContainer, Marker, Polyline, TileLayer, Tooltip, useMap } from 'react-leaflet';
import { useBuses, useDrivers, useRoutes } from '../data/baseData';
import { useRtdbValue, useServerNow } from '../data/hooks';
import { useOpenAlerts } from '../data/safetyAlerts';
import { NavIcon } from '../NavIcon';
import { describeAge, liveState, parseLive, STATE_LABEL, type LiveState } from '../lib/live';
import { decodePolyline } from '../lib/polyline';

const CAMPUS: [number, number] = [10.9027, 76.9006];

const COLOUR: Record<LiveState, string> = {
  live: '#1b7f3b',
  stale: '#b7791f',
  offline: '#8a8a8a',
  notRunning: '#8a8a8a',
};

const BUS_SVG =
  '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M4 16c0 .88.39 1.67 1 2.22V20a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h8v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1.78c.61-.55 1-1.34 1-2.22V6c0-3.5-3.58-4-8-4s-8 .5-8 4v10zm3.5 1a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm9 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zM18 11H6V6h12v5z"/></svg>';

/** A bus badge with its number's last digits, coloured by how fresh it is. */
function busIcon(number: string, state: LiveState) {
  const short = number.replace(/\s+/g, ' ').split(' ').slice(-1)[0];
  const label = short.replace(/[<>&"]/g, '');
  return L.divIcon({
    className: '',
    html: `<span class="bus-pin" style="background:${COLOUR[state]}">${BUS_SVG}${label}</span>`,
    iconSize: [0, 0],
  });
}

/** Every bus on one map with its route, driver and trip status. */
export function LiveMapPage() {
  const now = useServerNow();
  const live = useRtdbValue('live', parseLive);
  const buses = useBuses().data;
  const routes = useRoutes().data;
  const drivers = useDrivers().data;
  const [focus, setFocus] = useState<string | null>(null);

  const rows = useMemo(
    () =>
      buses
        .map((bus) => {
          const position = live.find((l) => l.busId === bus.id);
          return {
            bus,
            position,
            state: liveState(position, now),
            route: routes.find((r) => r.id === bus.routeId),
            driver: drivers.find((d) => d.uid === bus.driverId),
          };
        })
        .sort((a, b) => Number(a.state === 'notRunning') - Number(b.state === 'notRunning') || a.bus.number.localeCompare(b.bus.number)),
    [buses, live, routes, drivers, now],
  );
  const onRoad = rows.filter((r) => r.state !== 'notRunning' && r.position);
  const focused = rows.find((r) => r.bus.id === focus);
  const alerts = useOpenAlerts();
  const count = (s: LiveState[]) => rows.filter((r) => s.includes(r.state)).length;

  return (
    <section className="page">
      <div className="page-head">
        <h2>Live map</h2>
        <p className="muted">Green is live; amber means a weak signal (no update for 30 s); grey means the driver's phone is offline.</p>
      </div>
      <div className="stats">
        <Stat tone="ok" icon="buses" value={count(['live'])} label={`of ${buses.length} buses live`} />
        <Stat tone="warn" icon="history" value={count(['stale', 'offline'])} label="weak signal or offline" />
        <Stat tone="" icon="map" value={count(['notRunning'])} label="not running" />
        <Stat tone={alerts.length ? 'danger' : ''} icon="safety" value={alerts.length} label="open safety alerts" href="#/safety" />
      </div>
      <div className="map-and-list">
        <div className="map-frame">
          <MapContainer center={CAMPUS} zoom={11} scrollWheelZoom className="map">
            <TileLayer
              url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            />
            {onRoad.map(({ route }) =>
              route?.path ? (
                <Polyline key={`path-${route.id}`} positions={decodePolyline(route.path)} pathOptions={{ color: '#8c1d40', weight: 3, opacity: 0.35 }} />
              ) : null,
            )}
            {onRoad.map(({ bus, position, state, route, driver }) => (
              <Marker
                key={bus.id}
                position={[position!.lat, position!.lng]}
                icon={busIcon(bus.number, state)}
                eventHandlers={{ click: () => setFocus(bus.id) }}
              >
                <Tooltip direction="top" offset={[0, -10]}>
                  <strong>{bus.number}</strong>
                  <br />
                  {route?.name ?? 'No route'} · {driver?.name ?? 'No driver'}
                  <br />
                  {STATE_LABEL[state]} · {describeAge(now - position!.updatedAt)}
                </Tooltip>
              </Marker>
            ))}
            <FlyTo id={focus} target={focused?.position ? [focused.position.lat, focused.position.lng] : null} />
          </MapContainer>
        </div>
        <table className="table">
          <thead>
            <tr><th>Bus</th><th>Route</th><th>Driver</th><th>Status</th></tr>
          </thead>
          <tbody>
            {rows.map(({ bus, position, state, route, driver }) => (
              <tr
                key={bus.id}
                className={bus.id === focus ? 'selected' : undefined}
                onClick={() => position && state !== 'notRunning' && setFocus(bus.id)}
              >
                <td>{bus.number}</td>
                <td>{route?.name ?? '—'}</td>
                <td>{driver ? `${driver.name} (${driver.driverId})` : '—'}</td>
                <td>
                  <span className={`status status-${state}`}>{STATE_LABEL[state]}</span>
                  {position && state !== 'notRunning' && <span className="muted"> · {describeAge(now - position.updatedAt)}</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function FlyTo({ id, target }: { id: string | null; target: [number, number] | null }) {
  const map = useMap();
  useEffect(() => {
    if (target) map.flyTo(target, 15, { duration: 0.8 });
    // Only when a different bus is picked, not on every position update.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, map]);
  return null;
}

function Stat({ tone, icon, value, label, href }: { tone: string; icon: string; value: number; label: string; href?: string }) {
  const body = (
    <>
      <span className="stat-icon"><NavIcon name={icon} /></span>
      <span>
        <div className="stat-value">{value}</div>
        <div className="stat-label">{label}</div>
      </span>
    </>
  );
  return href ? <a className={`stat ${tone}`} href={href}>{body}</a> : <div className={`stat ${tone}`}>{body}</div>;
}
