import { useEffect, useState, type ReactNode } from 'react';
import { signOut } from 'firebase/auth';
import { auth } from './firebase';
import { BusIcon } from './BusIcon';
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
import { TripHistoryPage } from './pages/TripHistoryPage';

const pages = [
  { path: 'map', label: 'Live map', render: () => <LiveMapPage /> },
  { path: 'safety', label: 'Safety alerts', render: () => <SafetyPage /> },
  { path: 'reports', label: 'Reports', render: () => <ReportsPage /> },
  { path: 'history', label: 'Trip history', render: () => <TripHistoryPage /> },
  { path: 'buses', label: 'Buses', render: () => <BusesPage /> },
  { path: 'routes', label: 'Routes and stops', render: () => <RoutesPage /> },
  { path: 'drivers', label: 'Drivers', render: () => <DriversPage /> },
  { path: 'passes', label: 'Bus passes', render: () => <PassesPage /> },
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
      {sos.length > 0 && (
        <div className="sos-banner" role="alert">
          <span>SOS: {sos.map((a) => a.busNumber).join(', ')}</span>
          {path !== 'safety' && <a href="#/safety">See safety alerts</a>}
        </div>
      )}
      <div className="layout">
        <nav className="sidenav" aria-label="Sections">
          {pages.map((p) => (
            <a key={p.path} href={`#/${p.path}`} aria-current={p.path === path ? 'page' : undefined}>
              {p.label}
              {p.path === 'safety' && open.length > 0 && <span className="badge" aria-label={`${open.length} open`}>{open.length}</span>}
            </a>
          ))}
        </nav>
        <main className="content">{page.render()}</main>
      </div>
    </div>
  );
}
