import { useState, type FormEvent } from 'react';
import { httpsCallable } from 'firebase/functions';
import { FirebaseError } from 'firebase/app';
import { functions } from '../firebase';
import { byName, useBuses, useDrivers, type Driver } from '../data/baseData';

const createDriver = httpsCallable<{ driverId: string; name: string; pin: string }, { uid: string; driverId: string }>(functions, 'createDriver');
const setDriverPin = httpsCallable<{ uid: string; pin: string }, { ok: boolean }>(functions, 'setDriverPin');

const newPin = () => String(Math.floor(100000 + Math.random() * 900000));

function message(e: unknown): string {
  // Callable errors carry the server's own plain-words message.
  if (e instanceof FirebaseError && e.code !== 'functions/internal') return e.message;
  return "Couldn't reach the server. Check the connection and try again.";
}

/**
 * Driver sign-ins. Drivers sign in with their ID and a 6-digit PIN; the PIN
 * is shown once here, to hand to the driver, and is not stored anywhere
 * readable.
 */
export function DriversPage() {
  const drivers = useDrivers().data.slice().sort(byName);
  const buses = useBuses().data;
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState({ driverId: '', name: '', pin: newPin() });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [handOver, setHandOver] = useState<{ who: string; driverId: string; pin: string } | null>(null);

  async function add(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const result = await createDriver(form);
      setHandOver({ who: form.name.trim(), driverId: result.data.driverId, pin: form.pin });
      setAdding(false);
      setForm({ driverId: '', name: '', pin: newPin() });
    } catch (e) {
      setError(message(e));
    } finally {
      setBusy(false);
    }
  }

  async function resetPin(driver: Driver) {
    if (!window.confirm(`Give ${driver.name} a new PIN? The old one stops working.`)) return;
    const pin = newPin();
    try {
      await setDriverPin({ uid: driver.uid, pin });
      setHandOver({ who: driver.name, driverId: driver.driverId, pin });
    } catch (e) {
      setError(message(e));
    }
  }

  return (
    <section className="page">
      <div className="page-head">
        <h2>Drivers</h2>
        {!adding && <button className="primary" onClick={() => { setAdding(true); setHandOver(null); }}>Add driver</button>}
      </div>

      {handOver && (
        <div className="panel handover" role="status">
          <h3>Give these to {handOver.who}</h3>
          <p>Driver ID <strong>{handOver.driverId}</strong> · PIN <strong className="pin">{handOver.pin}</strong></p>
          <p className="muted">The PIN is shown only now. Assign the driver to a bus on the Buses page.</p>
          <button className="ghost" onClick={() => setHandOver(null)}>Done</button>
        </div>
      )}

      {adding && (
        <form className="panel form-grid" onSubmit={add}>
          <h3>New driver</h3>
          <label className="field"><span>Driver ID</span>
            <input value={form.driverId} placeholder="DRV003" onChange={(e) => setForm({ ...form, driverId: e.target.value.toUpperCase() })} />
          </label>
          <label className="field"><span>Name</span>
            <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </label>
          <label className="field"><span>PIN (6 digits)</span>
            <input value={form.pin} inputMode="numeric" maxLength={6} onChange={(e) => setForm({ ...form, pin: e.target.value.replace(/\D/g, '') })} />
          </label>
          {error && <p className="alert" role="alert">{error}</p>}
          <div className="actions">
            <button type="button" className="ghost" onClick={() => { setAdding(false); setError(null); }}>Cancel</button>
            <button className="primary" disabled={busy}>{busy ? 'Creating…' : 'Create driver'}</button>
          </div>
        </form>
      )}
      {!adding && error && <p className="alert" role="alert">{error}</p>}

      <table className="table">
        <thead><tr><th>Name</th><th>Driver ID</th><th>Bus</th><th /></tr></thead>
        <tbody>
          {drivers.map((d) => (
            <tr key={d.uid}>
              <td>{d.name}</td>
              <td>{d.driverId}</td>
              <td>{buses.find((b) => b.driverId === d.uid)?.number ?? <span className="muted">None</span>}</td>
              <td className="row-actions"><button className="ghost" onClick={() => resetPin(d)}>New PIN</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
