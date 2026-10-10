import { useEffect, useMemo, useState } from 'react';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip, useMap } from 'react-leaflet';
import { useBuses, useDrivers, useRoutes } from '../data/baseData';
import { useRtdbValue, useServerNow } from '../data/hooks';
import { describeAge, liveState, parseLive, STATE_LABEL, type LiveState } from '../lib/live';
import { decodePolyline } from '../lib/polyline';

const CAMPUS: [number, number] = [10.9027, 76.9006];

const COLOUR: Record<LiveState, string> = {
  live: '#1b7f3b',
  stale: '#8a8a8a',
  offline: '#8a8a8a',
  notRunning: '#8a8a8a',
};

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

  return (
    <section className="page">
      <h2>Live map</h2>
      <p className="muted">
        {onRoad.length} of {buses.length} buses on the road. Grey means no update for 30 seconds or the driver's phone is offline.
      </p>
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
              <CircleMarker
                key={bus.id}
                center={[position!.lat, position!.lng]}
                radius={11}
                pathOptions={{ color: '#fff', weight: 3, fillColor: COLOUR[state], fillOpacity: 1 }}
                eventHandlers={{ click: () => setFocus(bus.id) }}
              >
                <Tooltip direction="top" offset={[0, -10]}>
                  <strong>{bus.number}</strong>
                  <br />
                  {route?.name ?? 'No route'} · {driver?.name ?? 'No driver'}
                  <br />
                  {STATE_LABEL[state]} · {describeAge(now - position!.updatedAt)}
                </Tooltip>
              </CircleMarker>
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
