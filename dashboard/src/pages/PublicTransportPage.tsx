import { useMemo, useState, type FormEvent } from 'react';
import { addDoc, collection, deleteDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';
import { useQuery } from '../data/hooks';
import { byName, useRoutes } from '../data/baseData';

type Mode = 'bus' | 'train';
type Direction = 'toCampus' | 'fromCampus';

interface Departure {
  id: string;
  routeId: string;
  mode: Mode;
  name: string;
  from: string;
  to: string;
  departs: string;
  direction: Direction;
  note: string | null;
  fare: number | null;
}

const EMPTY = { routeId: '', mode: 'bus' as Mode, name: '', from: '', to: '', departs: '', direction: 'toCampus' as Direction, note: '', fare: '' };

/**
 * Public buses and trains students can take instead of a college bus. Shown
 * on the app's missed-bus screen for the matching route and direction.
 * Fixed timings (timetable/{id}), not live tracking.
 */
export function PublicTransportPage() {
  const routes = useRoutes().data.slice().sort(byName);
  const all = useQuery<Departure>(collection(db, 'timetable'), (id, d) => ({
    id,
    routeId: String(d.routeId ?? ''),
    mode: d.mode === 'train' ? 'train' : 'bus',
    name: String(d.name ?? ''),
    from: String(d.from ?? ''),
    to: String(d.to ?? ''),
    departs: String(d.departs ?? ''),
    direction: d.direction === 'fromCampus' ? 'fromCampus' : 'toCampus',
    note: typeof d.note === 'string' ? d.note : null,
    fare: typeof d.fare === 'number' ? d.fare : null,
  }), 'timetable').data;
  const [form, setForm] = useState(EMPTY);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const sorted = useMemo(
    () => all.slice().sort((a, b) =>
      a.routeId.localeCompare(b.routeId) || a.direction.localeCompare(b.direction) || a.departs.localeCompare(b.departs)),
    [all],
  );
  const routeName = (id: string) => routes.find((r) => r.id === id)?.name ?? id;

  async function add(event: FormEvent) {
    event.preventDefault();
    const fare = form.fare.trim() === '' ? null : Number(form.fare);
    if (!form.routeId) return setNotice('Choose the college route this helps.');
    if (!form.name.trim() || !form.from.trim() || !form.to.trim()) return setNotice('Fill in the name, from and to.');
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(form.departs)) return setNotice('Give the departure time.');
    if (fare !== null && (!Number.isFinite(fare) || fare < 0 || fare > 1000)) return setNotice('A fare must be between ₹0 and ₹1000.');
    setBusy(true);
    try {
      await addDoc(collection(db, 'timetable'), {
        routeId: form.routeId,
        mode: form.mode,
        name: form.name.trim(),
        from: form.from.trim(),
        to: form.to.trim(),
        departs: form.departs,
        direction: form.direction,
        note: form.note.trim() || null,
        fare,
      });
      setForm({ ...EMPTY, routeId: form.routeId, mode: form.mode, direction: form.direction, from: form.from, to: form.to });
      setNotice('Added. Students on that route see it on the missed-bus screen.');
    } catch {
      setNotice("Couldn't save. Check the connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  async function remove(d: Departure) {
    if (!window.confirm(`Remove ${d.name} at ${d.departs}?`)) return;
    try {
      await deleteDoc(doc(db, 'timetable', d.id));
    } catch {
      setNotice("Couldn't remove. Check the connection and try again.");
    }
  }

  const set = (key: keyof typeof EMPTY) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });

  return (
    <section className="page">
      <div className="page-head">
        <h2>Public transport</h2>
        <p className="muted">Town buses and trains students can take when they miss the college bus. Fixed timings, not live.</p>
      </div>
      <form className="panel form-grid" onSubmit={add}>
        <h3>Add a departure</h3>
        <label className="field"><span>For the college route</span>
          <select value={form.routeId} onChange={set('routeId')}>
            <option value="">Choose…</option>
            {routes.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
          </select>
        </label>
        <label className="field"><span>Bus or train</span>
          <select value={form.mode} onChange={set('mode')}>
            <option value="bus">Bus</option>
            <option value="train">Train</option>
          </select>
        </label>
        <label className="field"><span>Direction</span>
          <select value={form.direction} onChange={set('direction')}>
            <option value="toCampus">Morning, to campus</option>
            <option value="fromCampus">Evening, from campus</option>
          </select>
        </label>
        <label className="field"><span>Name</span>
          <input value={form.name} placeholder="e.g. Town bus 96A" maxLength={60} onChange={set('name')} />
        </label>
        <label className="field"><span>From</span>
          <input value={form.from} placeholder="e.g. Gandhipuram" maxLength={60} onChange={set('from')} />
        </label>
        <label className="field"><span>To</span>
          <input value={form.to} placeholder="e.g. Ettimadai" maxLength={60} onChange={set('to')} />
        </label>
        <label className="field"><span>Leaves at</span>
          <input type="time" value={form.departs} onChange={set('departs')} />
        </label>
        <label className="field"><span>Fare (₹, optional)</span>
          <input type="number" min={0} max={1000} value={form.fare} onChange={set('fare')} />
        </label>
        <label className="field wide"><span>Note (optional)</span>
          <input value={form.note} placeholder="e.g. Get off at Ettimadai stop and walk 10 minutes" maxLength={140} onChange={set('note')} />
        </label>
        {notice && <p className="muted" role="status">{notice}</p>}
        <div className="actions"><button className="primary" disabled={busy}>Add departure</button></div>
      </form>
      <table className="table">
        <thead><tr><th>College route</th><th>Direction</th><th>Leaves</th><th>Service</th><th>From → To</th><th>Fare</th><th /></tr></thead>
        <tbody>
          {sorted.map((d) => (
            <tr key={d.id}>
              <td>{routeName(d.routeId)}</td>
              <td>{d.direction === 'toCampus' ? 'Morning' : 'Evening'}</td>
              <td><strong>{d.departs}</strong></td>
              <td>{d.mode === 'train' ? '🚆' : '🚌'} {d.name}{d.note && <div className="muted">{d.note}</div>}</td>
              <td>{d.from} → {d.to}</td>
              <td>{d.fare === null ? '—' : `₹${d.fare}`}</td>
              <td className="row-actions"><button className="ghost danger" onClick={() => remove(d)}>Remove</button></td>
            </tr>
          ))}
          {sorted.length === 0 && <tr><td colSpan={7} className="muted">No public buses or trains yet.</td></tr>}
        </tbody>
      </table>
    </section>
  );
}
