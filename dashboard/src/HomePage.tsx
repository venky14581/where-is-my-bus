import { signOut } from 'firebase/auth';
import { auth } from './firebase';
import { BusIcon } from './BusIcon';

export function HomePage({ name }: { name: string }) {
  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand small">
          <span className="brand-badge"><BusIcon /></span>
          <strong>Where Is My Bus</strong>
          <span className="muted">Transport office</span>
        </div>
        <div className="topbar-user">
          <span>{name}</span>
          <button className="ghost" onClick={() => signOut(auth)}>Sign out</button>
        </div>
      </header>
      <main className="content">
        <h2>Welcome, {name}</h2>
        {/* Module 2 adds bus, route and stop management; Module 7 the fleet map. */}
        <section className="panel">
          <h3>No buses yet</h3>
          <p className="muted">
            Buses, routes and stops you add will appear here, followed by the live fleet map.
          </p>
        </section>
      </main>
    </div>
  );
}
