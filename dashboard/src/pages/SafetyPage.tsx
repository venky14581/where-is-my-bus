import { useState } from 'react';
import { CircleMarker, MapContainer, TileLayer, Tooltip } from 'react-leaflet';
import { collection, doc, limit, orderBy, query, serverTimestamp, updateDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { useQuery } from '../data/hooks';
import { ALERT_LABEL, alertFrom, describeAlert, sortAlerts, type SafetyAlert } from '../lib/safety';

const CAMPUS: [number, number] = [10.9027, 76.9006];
const when = (ms: number | null) =>
  ms === null ? 'just now' : new Date(ms).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' });

/** SOS, overspeed and off-route alerts: open ones first, to acknowledge. */
export function SafetyPage() {
  const alerts = sortAlerts(
    useQuery<SafetyAlert>(query(collection(db, 'safetyAlerts'), orderBy('at', 'desc'), limit(100)), alertFrom, 'all-alerts').data,
  );
  const [error, setError] = useState<string | null>(null);
  const open = alerts.filter((a) => a.status === 'open');
  const placed = alerts.filter((a) => a.lat !== null && a.lng !== null).slice(0, 30);

  async function acknowledge(alert: SafetyAlert) {
    setError(null);
    try {
      await updateDoc(doc(db, 'safetyAlerts', alert.id), {
        status: 'acknowledged',
        acknowledgedBy: auth.currentUser?.uid,
        acknowledgedAt: serverTimestamp(),
      });
    } catch {
      setError("Couldn't save. Check the connection and try again.");
    }
  }

  return (
    <section className="page">
      <h2>Safety alerts</h2>
      <p className="muted">
        {open.length ? `${open.length} open.` : 'Nothing open.'} SOS comes from a driver or a student on the bus and shows where the bus was.
        Overspeeding and leaving the route are noticed by the driver's phone. Speed limit: Settings.
      </p>
      {error && <p className="alert" role="alert">{error}</p>}
      <div className="map-and-list">
        <div className="map-frame">
          <MapContainer center={placed[0] ? [placed[0].lat!, placed[0].lng!] : CAMPUS} zoom={11} scrollWheelZoom className="map">
            <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' />
            {placed.map((a) => (
              <CircleMarker key={a.id} center={[a.lat!, a.lng!]} radius={a.type === 'sos' ? 12 : 9}
                pathOptions={{ color: '#fff', weight: 3, fillColor: a.status === 'open' ? '#c62828' : '#8a8a8a', fillOpacity: 1 }}>
                <Tooltip>{ALERT_LABEL[a.type]} · {a.busNumber} · {when(a.at)}</Tooltip>
              </CircleMarker>
            ))}
          </MapContainer>
        </div>
        <ul className="alert-list">
          {alerts.length === 0 && <li className="muted">No alerts yet.</li>}
          {alerts.map((a) => (
            <li key={a.id} className={`alert-item ${a.status} ${a.type}`}>
              <div>
                <strong>{ALERT_LABEL[a.type]}</strong> · {a.busNumber}{a.routeName && ` · ${a.routeName}`}
                <div>{describeAlert(a)}</div>
                <div className="muted">
                  {when(a.at)}{a.driverName && ` · driver ${a.driverName}`}
                  {a.lat !== null && a.lng !== null && (
                    <> · <a href={`https://www.openstreetmap.org/?mlat=${a.lat}&mlon=${a.lng}#map=17/${a.lat}/${a.lng}`} target="_blank" rel="noreferrer">open map</a></>
                  )}
                </div>
              </div>
              {a.status === 'open'
                ? <button className="primary" onClick={() => acknowledge(a)}>Acknowledge</button>
                : <span className="muted">Acknowledged {when(a.acknowledgedAt)}</span>}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
