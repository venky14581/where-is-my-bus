import { useState } from 'react';
import { collection, doc, getDocs, query, serverTimestamp, where, writeBatch } from 'firebase/firestore';
import { CircleMarker, MapContainer, Polyline, TileLayer, Tooltip, useMapEvents } from 'react-leaflet';
import { db } from '../firebase';
import { byName, useRoutes, type Route } from '../data/baseData';
import { buildPath, routeDocument, routeProblems, slugify, withStopIds, type RouteDraft, type RoutePath, type StopDraft } from '../lib/routeEdit';
import { decodePolyline } from '../lib/polyline';

const CAMPUS: [number, number] = [10.9027, 76.9006];

/** Routes, their stops in travel order and the morning timetable. */
export function RoutesPage() {
  const routes = useRoutes();
  const [editing, setEditing] = useState<Route | 'new' | null>(null);

  if (editing) {
    return (
      <RouteEditor
        route={editing === 'new' ? undefined : editing}
        existingIds={routes.data.map((r) => r.id)}
        onDone={() => setEditing(null)}
      />
    );
  }
  return (
    <section className="page">
      <div className="page-head">
        <h2>Routes and stops</h2>
        <button className="primary" onClick={() => setEditing('new')}>Add route</button>
      </div>
      <table className="table">
        <thead>
          <tr><th>Route</th><th>City</th><th>Stops</th><th>First pickup</th><th>Shown to students</th><th /></tr>
        </thead>
        <tbody>
          {routes.data.slice().sort(byName).map((route) => (
            <tr key={route.id}>
              <td>{route.name}</td>
              <td>{route.city}</td>
              <td>{route.stops.length}</td>
              <td>{route.stops[0]?.scheduledTime ?? '—'}</td>
              <td>{route.active ? 'Yes' : 'No'}</td>
              <td className="row-actions"><button className="ghost" onClick={() => setEditing(route)}>Edit</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function RouteEditor({ route, existingIds, onDone }: { route?: Route; existingIds: string[]; onDone: () => void }) {
  const [draft, setDraft] = useState<RouteDraft>(() => ({
    name: route?.name ?? '',
    city: route?.city ?? '',
    active: route?.active ?? true,
    guestFare: route?.guestFare ?? null,
    stops: route?.stops.map(({ id, name, lat, lng, scheduledTime }) => ({ id, name, lat, lng, scheduledTime })) ?? [],
  }));
  const [placing, setPlacing] = useState<number | null>(null);
  const [problems, setProblems] = useState<string[]>([]);
  const [offRoad, setOffRoad] = useState<{ path: RoutePath; stops: StopDraft[] } | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const setStop = (i: number, patch: Partial<StopDraft>) =>
    setDraft((d) => ({ ...d, stops: d.stops.map((s, j) => (j === i ? { ...s, ...patch } : s)) }));
  const move = (i: number, by: -1 | 1) =>
    setDraft((d) => {
      const stops = d.stops.slice();
      [stops[i], stops[i + by]] = [stops[i + by], stops[i]];
      return { ...d, stops };
    });
  const removeStop = (i: number) => {
    setDraft((d) => ({ ...d, stops: d.stops.filter((_, j) => j !== i) }));
    setPlacing(null);
  };

  function onMapClick(lat: number, lng: number) {
    const point = { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
    if (placing !== null) {
      setStop(placing, point);
      setPlacing(null);
    } else {
      setDraft((d) => ({ ...d, stops: [...d.stops, { id: '', name: '', scheduledTime: '', ...point }] }));
    }
  }

  /** Checks, finds the road path, and writes. Stops at the first thing the office must confirm. */
  async function save() {
    setStatus(null);
    setOffRoad(null);
    const found = routeProblems(draft);
    setProblems(found);
    if (found.length) return;
    setSaving(true);
    try {
      const stops = withStopIds(draft.stops);
      setDraft((d) => ({ ...d, stops }));

      // Students whose stop disappears will be asked to pick again.
      if (route) {
        const kept = new Set(stops.map((s) => s.id));
        const riders = await getDocs(query(collection(db, 'users'), where('routeId', '==', route.id)));
        const affected = riders.docs.filter((d) => typeof d.get('stopId') === 'string' && !kept.has(d.get('stopId'))).length;
        if (affected > 0 && !window.confirm(`${affected} student(s) chose a stop you removed. They will be asked to choose again. Save?`)) return;
      }

      setStatus('Finding the road route…');
      const path = await buildPath(stops.map((s) => ({ id: s.id, lat: s.lat!, lng: s.lng! })));
      setStatus(null);
      if (path.offRoad.length > 0) {
        setOffRoad({ path, stops });
        return;
      }
      await write(stops, path);
    } catch (e) {
      setStatus(e instanceof Error && e.message.startsWith('Could not find') ? e.message : "Couldn't save. Check the connection and try again.");
    } finally {
      setSaving(false);
    }
  }

  async function write(stops: StopDraft[], path: RoutePath) {
    const id = route?.id ?? uniqueId(slugify(`${draft.city}-${draft.name}`), existingIds);
    const batch = writeBatch(db);
    batch.set(doc(db, 'routes', id), { ...routeDocument({ ...draft, stops }, path), updatedAt: serverTimestamp() });
    if (!route) batch.set(doc(db, 'routeAccess', id), { acceptsFrom: [] });
    await batch.commit();
    onDone();
  }

  /** After the off-road warning: save exactly what was checked. */
  async function saveAnyway() {
    if (!offRoad) return;
    setSaving(true);
    try {
      await write(offRoad.stops, offRoad.path);
    } catch {
      setStatus("Couldn't save. Check the connection and try again.");
    } finally {
      setSaving(false);
    }
  }

  const savedPath = route?.path ? decodePolyline(route.path) : null;
  const placed = draft.stops.filter((s) => s.lat !== null && s.lng !== null) as (StopDraft & { lat: number; lng: number })[];

  return (
    <section className="page">
      <div className="page-head">
        <h2>{route ? `Edit ${route.name}` : 'New route'}</h2>
        <button className="ghost" onClick={onDone}>Back to routes</button>
      </div>
      <div className="panel form-grid">
        <label className="field"><span>Route name</span>
          <input value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} placeholder="Gandhipuram – Campus" />
        </label>
        <label className="field"><span>City</span>
          <input value={draft.city} onChange={(e) => setDraft({ ...draft, city: e.target.value })} placeholder="Coimbatore" />
        </label>
        <label className="field"><span>Guest fare (₹, evening seats)</span>
          <input type="number" min={0} max={1000} value={draft.guestFare ?? ''}
            onChange={(e) => setDraft({ ...draft, guestFare: e.target.value === '' ? null : Number(e.target.value) })} />
        </label>
        <label className="field checkbox">
          <input type="checkbox" checked={draft.active} onChange={(e) => setDraft({ ...draft, active: e.target.checked })} />
          <span>Shown to students</span>
        </label>
      </div>

      <p className="muted">
        Stops go in morning travel order and end at the campus. {placing !== null
          ? `Click the map to place stop ${placing + 1}.`
          : 'Click the map to add a stop there, or Place to move one.'}
      </p>
      <div className="map-and-list">
        <div className="map-frame">
          <MapContainer center={placed[0] ? [placed[0].lat, placed[0].lng] : CAMPUS} zoom={12} className={`map${placing !== null ? ' placing' : ''}`}>
            <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' />
            <ClickToPlace onClick={onMapClick} />
            {savedPath && <Polyline positions={savedPath} pathOptions={{ color: '#8c1d40', weight: 4, opacity: 0.4 }} />}
            {draft.stops.map((s, i) => s.lat !== null && s.lng !== null && (
              <CircleMarker key={i} center={[s.lat, s.lng]} radius={9}
                pathOptions={{ color: '#fff', weight: 2, fillColor: i === placing ? '#c77700' : '#8c1d40', fillOpacity: 1 }}>
                <Tooltip permanent direction="right" offset={[8, 0]}>{i + 1}. {s.name || 'New stop'}</Tooltip>
              </CircleMarker>
            ))}
          </MapContainer>
        </div>
        <table className="table stops">
          <thead><tr><th>#</th><th>Stop</th><th>Time</th><th>Position</th><th /></tr></thead>
          <tbody>
            {draft.stops.map((s, i) => (
              <tr key={i} className={i === placing ? 'selected' : undefined}>
                <td>{i + 1}</td>
                <td><input aria-label={`Stop ${i + 1} name`} value={s.name} onChange={(e) => setStop(i, { name: e.target.value })} /></td>
                <td><input aria-label={`Stop ${i + 1} time`} type="time" value={s.scheduledTime} onChange={(e) => setStop(i, { scheduledTime: e.target.value })} /></td>
                <td className="muted">{s.lat !== null && s.lng !== null ? `${s.lat.toFixed(4)}, ${s.lng.toFixed(4)}` : 'Not placed'}</td>
                <td className="row-actions">
                  <button type="button" className="ghost" onClick={() => setPlacing(placing === i ? null : i)}>{placing === i ? 'Cancel' : 'Place'}</button>
                  <button type="button" className="ghost" aria-label="Move up" disabled={i === 0} onClick={() => move(i, -1)}>↑</button>
                  <button type="button" className="ghost" aria-label="Move down" disabled={i === draft.stops.length - 1} onClick={() => move(i, 1)}>↓</button>
                  <button type="button" className="ghost danger" onClick={() => removeStop(i)}>Remove</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {problems.length > 0 && (
        <div className="alert" role="alert"><ul>{problems.map((p) => <li key={p}>{p}</li>)}</ul></div>
      )}
      {offRoad && (
        <div className="alert warning" role="alert">
          <p>These stops are away from the road the bus takes. The driver's phone only records a stop within 80 m, so they would never show as passed:</p>
          <ul>{offRoad.path.offRoad.map((o) => (
            <li key={o.stopId}>{offRoad.stops.find((s) => s.id === o.stopId)?.name}: {o.metres} m from the road</li>
          ))}</ul>
          <p>Move them to the roadside, or save anyway.</p>
          <button className="ghost" disabled={saving} onClick={saveAnyway}>Save anyway</button>
        </div>
      )}
      {status && <p className="muted" role="status">{status}</p>}
      <div className="actions">
        <button className="ghost" onClick={onDone}>Cancel</button>
        <button className="primary" disabled={saving} onClick={save}>{saving ? 'Saving…' : 'Save route'}</button>
      </div>
    </section>
  );
}

function ClickToPlace({ onClick }: { onClick: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onClick(e.latlng.lat, e.latlng.lng) });
  return null;
}

function uniqueId(base: string, taken: string[]): string {
  let id = base;
  for (let n = 2; taken.includes(id); n++) id = `${base}-${n}`;
  return id;
}
