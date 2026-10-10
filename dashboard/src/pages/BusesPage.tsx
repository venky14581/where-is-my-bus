import { useState, type FormEvent } from 'react';
import { deleteDoc, doc, writeBatch } from 'firebase/firestore';
import { db } from '../firebase';
import { byName, useBuses, useDrivers, useRoutes, type Bus } from '../data/baseData';
import { slugify } from '../lib/routeEdit';

type Draft = { id: string | null; number: string; capacity: string; routeId: string; driverId: string };

const blank: Draft = { id: null, number: '', capacity: '50', routeId: '', driverId: '' };

/** Buses, their seat capacity, route and assigned driver. */
export function BusesPage() {
  const buses = useBuses();
  const routes = useRoutes().data.slice().sort(byName);
  const drivers = useDrivers().data.slice().sort(byName);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const edit = (bus: Bus) =>
    setDraft({ id: bus.id, number: bus.number, capacity: String(bus.capacity), routeId: bus.routeId ?? '', driverId: bus.driverId ?? '' });

  async function save(event: FormEvent) {
    event.preventDefault();
    if (!draft) return;
    const number = draft.number.trim().toUpperCase();
    const capacity = Number(draft.capacity);
    if (!number) return setError('Enter the bus number, e.g. TN 37 AB 1201.');
    if (!Number.isInteger(capacity) || capacity < 1 || capacity > 120) return setError('Seats must be a whole number from 1 to 120.');
    const id = draft.id ?? `bus-${slugify(number)}`;
    if (!draft.id && buses.data.some((b) => b.id === id)) return setError(`Bus ${number} already exists.`);

    setSaving(true);
    setError(null);
    try {
      const batch = writeBatch(db);
      // A driver drives one bus: take them off any other bus first.
      if (draft.driverId) {
        for (const other of buses.data) {
          if (other.id !== id && other.driverId === draft.driverId) batch.update(doc(db, 'buses', other.id), { driverId: null });
        }
      }
      batch.set(doc(db, 'buses', id), {
        number,
        capacity,
        routeId: draft.routeId || null,
        driverId: draft.driverId || null,
      });
      await batch.commit();
      setDraft(null);
    } catch {
      setError("Couldn't save. Check the connection and try again.");
    } finally {
      setSaving(false);
    }
  }

  async function remove(bus: Bus) {
    if (!window.confirm(`Delete bus ${bus.number}? Students on ${routes.find((r) => r.id === bus.routeId)?.name ?? 'its route'} will see no bus.`)) return;
    await deleteDoc(doc(db, 'buses', bus.id));
  }

  return (
    <section className="page">
      <div className="page-head">
        <h2>Buses</h2>
        {!draft && <button className="primary" onClick={() => setDraft(blank)}>Add bus</button>}
      </div>

      {draft && (
        <form className="panel form-grid" onSubmit={save}>
          <h3>{draft.id ? `Edit ${draft.number}` : 'New bus'}</h3>
          <label className="field">
            <span>Bus number</span>
            <input value={draft.number} disabled={!!draft.id} onChange={(e) => setDraft({ ...draft, number: e.target.value })} />
          </label>
          <label className="field">
            <span>Seats</span>
            <input type="number" min={1} max={120} value={draft.capacity} onChange={(e) => setDraft({ ...draft, capacity: e.target.value })} />
          </label>
          <label className="field">
            <span>Route</span>
            <select value={draft.routeId} onChange={(e) => setDraft({ ...draft, routeId: e.target.value })}>
              <option value="">No route</option>
              {routes.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Driver</span>
            <select value={draft.driverId} onChange={(e) => setDraft({ ...draft, driverId: e.target.value })}>
              <option value="">No driver</option>
              {drivers.map((d) => {
                const elsewhere = buses.data.find((b) => b.driverId === d.uid && b.id !== draft.id);
                return (
                  <option key={d.uid} value={d.uid}>
                    {d.name} ({d.driverId}){elsewhere ? ` – now on ${elsewhere.number}, will move` : ''}
                  </option>
                );
              })}
            </select>
          </label>
          {error && <p className="alert" role="alert">{error}</p>}
          <div className="actions">
            <button type="button" className="ghost" onClick={() => { setDraft(null); setError(null); }}>Cancel</button>
            <button className="primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
          </div>
        </form>
      )}

      <table className="table">
        <thead>
          <tr><th>Bus</th><th>Seats</th><th>Route</th><th>Driver</th><th /></tr>
        </thead>
        <tbody>
          {buses.data.slice().sort((a, b) => a.number.localeCompare(b.number)).map((bus) => {
            const driver = drivers.find((d) => d.uid === bus.driverId);
            return (
              <tr key={bus.id}>
                <td>{bus.number}</td>
                <td>{bus.capacity}</td>
                <td>{routes.find((r) => r.id === bus.routeId)?.name ?? <span className="muted">No route</span>}</td>
                <td>{driver ? `${driver.name} (${driver.driverId})` : <span className="muted">No driver</span>}</td>
                <td className="row-actions">
                  <button className="ghost" onClick={() => edit(bus)}>Edit</button>
                  <button className="ghost danger" onClick={() => remove(bus)}>Delete</button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </section>
  );
}
