import { useState, type FormEvent } from 'react';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { useDocument } from '../data/hooks';
import { byName, useRoutes, type Route } from '../data/baseData';

export interface BookingSettings {
  /** Guest booking opens at this time the evening before the trip. */
  opensAt: string;
  /** And closes this many minutes before the bus leaves. */
  closesMinutesBefore: number;
}

// From the planning decisions: open at 6 pm the day before, close 20 to 30
// minutes before departure.
const DEFAULTS: BookingSettings = { opensAt: '18:00', closesMinutesBefore: 30 };

/** Guest fares and the booking window for evening seats (used from Module 10). */
export function SettingsPage() {
  const saved = useDocument(doc(db, 'settings', 'booking'), (d) => ({
    opensAt: typeof d?.opensAt === 'string' ? d.opensAt : DEFAULTS.opensAt,
    closesMinutesBefore: typeof d?.closesMinutesBefore === 'number' ? d.closesMinutesBefore : DEFAULTS.closesMinutesBefore,
  }), 'settings/booking');
  const routes = useRoutes().data.slice().sort(byName);
  const [notice, setNotice] = useState<string | null>(null);

  return (
    <section className="page">
      <h2>Fares and booking</h2>
      {notice && <p className="muted" role="status">{notice}</p>}
      {/* Keyed by the saved values, so the form restarts from them when they change. */}
      <BookingForm key={`${saved.data.opensAt}|${saved.data.closesMinutesBefore}`} initial={saved.data} onNotice={setNotice} />

      <h3>Guest fare per route</h3>
      <p className="muted">What a student without a pass pays for one evening seat. Leave empty to offer no guest seats on that route.</p>
      <table className="table">
        <thead><tr><th>Route</th><th>Fare (₹)</th><th /></tr></thead>
        <tbody>
          {routes.map((r) => <FareRow key={`${r.id}|${r.guestFare}`} route={r} onNotice={setNotice} />)}
        </tbody>
      </table>
    </section>
  );
}

function BookingForm({ initial, onNotice }: { initial: BookingSettings; onNotice: (m: string) => void }) {
  const [booking, setBooking] = useState(initial);

  async function save(event: FormEvent) {
    event.preventDefault();
    try {
      await setDoc(doc(db, 'settings', 'booking'), booking);
      onNotice('Booking window saved.');
    } catch {
      onNotice("Couldn't save. Check the connection and try again.");
    }
  }

  return (
    <form className="panel form-grid" onSubmit={save}>
      <h3>Booking window for evening seats</h3>
      <label className="field"><span>Opens the evening before at</span>
        <input type="time" value={booking.opensAt} onChange={(e) => setBooking({ ...booking, opensAt: e.target.value })} />
      </label>
      <label className="field"><span>Closes before departure</span>
        <select value={booking.closesMinutesBefore} onChange={(e) => setBooking({ ...booking, closesMinutesBefore: Number(e.target.value) })}>
          <option value={20}>20 minutes</option>
          <option value={30}>30 minutes</option>
        </select>
      </label>
      <div className="actions"><button className="primary">Save booking window</button></div>
    </form>
  );
}

function FareRow({ route, onNotice }: { route: Route; onNotice: (m: string) => void }) {
  const [value, setValue] = useState(route.guestFare === null ? '' : String(route.guestFare));

  async function save() {
    const fare = value.trim() === '' ? null : Number(value);
    if (fare !== null && (!Number.isFinite(fare) || fare < 0 || fare > 1000)) {
      return onNotice('A fare must be between ₹0 and ₹1000, or empty for no guest seats.');
    }
    try {
      await updateDoc(doc(db, 'routes', route.id), { guestFare: fare });
      onNotice(`Fare saved for ${route.name}.`);
    } catch {
      onNotice("Couldn't save. Check the connection and try again.");
    }
  }

  return (
    <tr>
      <td>{route.name}</td>
      <td>
        <input aria-label={`Fare for ${route.name}`} type="number" min={0} max={1000} value={value} onChange={(e) => setValue(e.target.value)} />
      </td>
      <td className="row-actions"><button className="ghost" onClick={save}>Save</button></td>
    </tr>
  );
}
