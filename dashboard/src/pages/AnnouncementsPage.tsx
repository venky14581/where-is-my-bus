import { useState, type FormEvent } from 'react';
import { addDoc, collection, limit, orderBy, query, serverTimestamp, type Timestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { useQuery } from '../data/hooks';
import { byName, useRoutes } from '../data/baseData';

interface Sent {
  id: string;
  routeId: string | null;
  title: string;
  body: string;
  createdAt: Date | null;
}

/** Messages to one route's riders or to every student. Sent as push notifications and shown in the app. */
export function AnnouncementsPage() {
  const routes = useRoutes().data.slice().sort(byName);
  const sent = useQuery<Sent>(
    query(collection(db, 'announcements'), orderBy('createdAt', 'desc'), limit(20)),
    (id, d) => ({
      id,
      routeId: typeof d.routeId === 'string' ? d.routeId : null,
      title: String(d.title ?? ''),
      body: String(d.body ?? ''),
      createdAt: (d.createdAt as Timestamp | null)?.toDate() ?? null,
    }),
    'announcements',
  );
  const [form, setForm] = useState({ routeId: '', title: '', body: '' });
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  async function send(event: FormEvent) {
    event.preventDefault();
    if (!form.title.trim()) return setNotice('Add a title.');
    const audience = form.routeId ? routes.find((r) => r.id === form.routeId)?.name : 'all students';
    if (!window.confirm(`Send "${form.title.trim()}" to ${audience}?`)) return;
    setBusy(true);
    setNotice(null);
    try {
      await addDoc(collection(db, 'announcements'), {
        routeId: form.routeId || null,
        title: form.title.trim(),
        body: form.body.trim(),
        createdAt: serverTimestamp(),
        createdBy: auth.currentUser!.uid,
      });
      setForm({ routeId: form.routeId, title: '', body: '' });
      setNotice(`Sent to ${audience}.`);
    } catch {
      setNotice("Couldn't send. Check the connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page">
      <h2>Announcements</h2>
      <form className="panel form-grid" onSubmit={send}>
        <label className="field"><span>To</span>
          <select value={form.routeId} onChange={(e) => setForm({ ...form, routeId: e.target.value })}>
            <option value="">All students</option>
            {routes.map((r) => <option key={r.id} value={r.id}>Riders of {r.name}</option>)}
          </select>
        </label>
        <label className="field"><span>Title</span>
          <input value={form.title} maxLength={80} placeholder="Holiday on Monday" onChange={(e) => setForm({ ...form, title: e.target.value })} />
        </label>
        <label className="field wide"><span>Message</span>
          <textarea value={form.body} maxLength={500} rows={3} placeholder="No college buses run on Monday." onChange={(e) => setForm({ ...form, body: e.target.value })} />
        </label>
        {notice && <p className="muted" role="status">{notice}</p>}
        <div className="actions"><button className="primary" disabled={busy}>{busy ? 'Sending…' : 'Send'}</button></div>
      </form>

      <h3>Sent recently</h3>
      <table className="table">
        <thead><tr><th>When</th><th>To</th><th>Message</th></tr></thead>
        <tbody>
          {sent.data.map((a) => (
            <tr key={a.id}>
              <td>{a.createdAt?.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) ?? '…'}</td>
              <td>{a.routeId ? routes.find((r) => r.id === a.routeId)?.name ?? a.routeId : 'All students'}</td>
              <td><strong>{a.title}</strong>{a.body && <div className="muted">{a.body}</div>}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
