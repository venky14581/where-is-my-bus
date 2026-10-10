import { useMemo, useState } from 'react';
import { collection, doc, query, updateDoc, where } from 'firebase/firestore';
import { db } from '../firebase';
import { useQuery } from '../data/hooks';
import { byName, useRoutes } from '../data/baseData';
import { campusToday as today, passState } from '../lib/passes';

interface Student {
  uid: string;
  name: string;
  email: string;
  routeId: string | null;
  stopId: string | null;
  passValid: boolean;
  passValidUntil: string | null;
}


/**
 * Digital bus passes. A valid pass shows as a rotating QR in the student's
 * app; the driver scans it at boarding and the server checks it.
 */
export function PassesPage() {
  const students = useQuery<Student>(query(collection(db, 'users'), where('role', '==', 'student')), (uid, d) => ({
    uid,
    name: String(d.name ?? ''),
    email: String(d.email ?? ''),
    routeId: typeof d.routeId === 'string' ? d.routeId : null,
    stopId: typeof d.stopId === 'string' ? d.stopId : null,
    passValid: d.passValid === true,
    passValidUntil: typeof d.passValidUntil === 'string' ? d.passValidUntil : null,
  }), 'students');
  const routes = useRoutes().data.slice().sort(byName);
  const [routeFilter, setRouteFilter] = useState('');
  const [search, setSearch] = useState('');
  // Default end date: the end of the academic year.
  const [until, setUntil] = useState(() => `${new Date().getFullYear() + (new Date().getMonth() >= 5 ? 1 : 0)}-05-31`);
  const [notice, setNotice] = useState<string | null>(null);

  const shown = useMemo(() => {
    const term = search.trim().toLowerCase();
    return students.data
      .filter((s) => !routeFilter || s.routeId === routeFilter)
      .filter((s) => !term || s.name.toLowerCase().includes(term) || s.email.includes(term))
      .sort(byName);
  }, [students.data, routeFilter, search]);

  async function setPass(student: Student, valid: boolean) {
    if (valid && until < today()) return setNotice('Pick an end date that is not in the past.');
    if (!valid && !window.confirm(`Cancel ${student.name}'s pass? Their QR stops working at once.`)) return;
    try {
      await updateDoc(doc(db, 'users', student.uid), valid
        ? { passValid: true, passValidUntil: until }
        : { passValid: false });
      setNotice(valid ? `${student.name}'s pass is valid until ${until}.` : `${student.name}'s pass is cancelled.`);
    } catch {
      setNotice("Couldn't save. Check the connection and try again.");
    }
  }

  const routeName = (id: string | null) => routes.find((r) => r.id === id)?.name ?? '—';
  const stopName = (s: Student) => routes.find((r) => r.id === s.routeId)?.stops.find((x) => x.id === s.stopId)?.name ?? '—';

  return (
    <section className="page">
      <h2>Bus passes</h2>
      <div className="panel form-grid">
        <label className="field"><span>Route</span>
          <select value={routeFilter} onChange={(e) => setRouteFilter(e.target.value)}>
            <option value="">All routes</option>
            {routes.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
          </select>
        </label>
        <label className="field"><span>Search</span>
          <input value={search} placeholder="Name or email" onChange={(e) => setSearch(e.target.value)} />
        </label>
        <label className="field"><span>New passes valid until</span>
          <input type="date" value={until} onChange={(e) => setUntil(e.target.value)} />
        </label>
      </div>
      {notice && <p className="muted" role="status">{notice}</p>}
      <table className="table">
        <thead><tr><th>Student</th><th>Route and stop</th><th>Pass</th><th /></tr></thead>
        <tbody>
          {shown.map((s) => {
            const state = passState(s);
            return (
              <tr key={s.uid}>
                <td>{s.name}<div className="muted">{s.email}</div></td>
                <td>{routeName(s.routeId)}<div className="muted">{stopName(s)}</div></td>
                <td>
                  {state === 'valid' && <span className="status status-live">Valid until {s.passValidUntil}</span>}
                  {state === 'expired' && <span className="status status-offline">Expired {s.passValidUntil}</span>}
                  {state === 'none' && <span className="muted">No pass</span>}
                </td>
                <td className="row-actions">
                  <button className="ghost" onClick={() => setPass(s, true)}>
                    {state === 'valid' ? `Extend to ${until}` : `Issue to ${until}`}
                  </button>
                  {state !== 'none' && <button className="ghost danger" onClick={() => setPass(s, false)}>Cancel</button>}
                </td>
              </tr>
            );
          })}
          {shown.length === 0 && <tr><td colSpan={4} className="muted">No students match.</td></tr>}
        </tbody>
      </table>
    </section>
  );
}
