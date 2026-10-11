import { useEffect, useState, type ReactNode } from 'react';
import { signOut } from 'firebase/auth';
import { auth } from './firebase';
import { BusIcon } from './BusIcon';
import { NavIcon } from './NavIcon';
import { LiveMapPage } from './pages/LiveMapPage';
import { BusesPage } from './pages/BusesPage';
import { RoutesPage } from './pages/RoutesPage';
import { DriversPage } from './pages/DriversPage';
import { PassesPage } from './pages/PassesPage';
import { AnnouncementsPage } from './pages/AnnouncementsPage';
import { SettingsPage } from './pages/SettingsPage';
import { ReportsPage } from './pages/ReportsPage';
import { SafetyPage } from './pages/SafetyPage';
import { useOpenAlerts } from './data/safetyAlerts';
import { LiveAlerts } from './LiveAlerts';
import { TripHistoryPage } from './pages/TripHistoryPage';
import { PublicTransportPage } from './pages/PublicTransportPage';

const pages = [
  { path: 'map', label: 'Live map', render: () => <LiveMapPage /> },
  { path: 'safety', label: 'Safety alerts', render: () => <SafetyPage /> },
  { path: 'reports', label: 'Reports', render: () => <ReportsPage /> },
  { path: 'history', label: 'Trip history', render: () => <TripHistoryPage /> },
  { path: 'buses', label: 'Buses', render: () => <BusesPage /> },
  { path: 'routes', label: 'Routes and stops', render: () => <RoutesPage /> },
  { path: 'drivers', label: 'Drivers', render: () => <DriversPage /> },
  { path: 'passes', label: 'Bus passes', render: () => <PassesPage /> },
  { path: 'transit', label: 'Public transport', render: () => <PublicTransportPage /> },
  { path: 'announcements', label: 'Announcements', render: () => <AnnouncementsPage /> },
  { path: 'settings', label: 'Settings', render: () => <SettingsPage /> },
] as const satisfies readonly { path: string; label: string; render: () => ReactNode }[];

function currentPath(): string {
  const hash = window.location.hash.replace(/^#\/?/, '');
  return pages.some((p) => p.path === hash) ? hash : 'map';
}

/** Pages are addressed as #/map, #/buses and so on, so links and reloads work. */
export function Shell({ name }: { name: string }) {
  const [path, setPath] = useState(currentPath);
  useEffect(() => {
    const onHash = () => setPath(currentPath());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);
  const page = pages.find((p) => p.path === path) ?? pages[0];
  const open = useOpenAlerts();
  const sos = open.filter((a) => a.type === 'sos');

  return (
    <div className="shell">
      <aside className="sidenav" aria-label="Sections">
        <div className="brand side-brand">
          <span className="brand-badge"><BusIcon /></span>
          <div>
            <strong>Where Is My Bus</strong>
            <span>Transport office</span>
          </div>
        </div>
        <nav className="nav-links">
          {pages.map((p) => (
            <a key={p.path} href={`#/${p.path}`} aria-current={p.path === path ? 'page' : undefined}>
              <NavIcon name={p.path} />
              <span>{p.label}</span>
              {p.path === 'safety' && open.length > 0 && <span className="badge" aria-label={`${open.length} open`}>{open.length}</span>}
            </a>
          ))}
        </nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <Today />
          <div className="topbar-user">
            <LiveAlerts />
            <span className="user-chip" title={name}>
              <span className="avatar" aria-hidden="true">{initials(name)}</span>
              <span className="user-name">{name}</span>
            </span>
            <button className="ghost" onClick={() => signOut(auth)}>Sign out</button>
          </div>
        </header>
        {sos.length > 0 && (
          <div className="sos-banner" role="alert">
            <span>SOS: {sos.map((a) => a.busNumber).join(', ')}</span>
            {path !== 'safety' && <a href="#/safety">See safety alerts</a>}
          </div>
        )}
        <main className="content" key={page.path}>{page.render()}</main>
      </div>
    </div>
  );
}

const initials = (name: string) =>
  name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]!.toUpperCase()).join('') || 'TO';

/** Today's date and the time, on the campus clock, ticking each minute. */
function Today() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(timer);
  }, []);
  const day = now.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Asia/Kolkata' });
  const time = now.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' });
  return (
    <div className="today">
      <strong>{time}</strong>
      <span className="muted">{day}</span>
    </div>
  );
}
