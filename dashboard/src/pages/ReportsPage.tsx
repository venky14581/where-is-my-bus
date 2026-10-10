import { useMemo, useState } from 'react';
import { BarChart } from '../BarChart';
import { SERIES_COLOURS } from '../lib/colours';
import { byName, useBuses, useRoutes } from '../data/baseData';
import { campusToday, useReportData } from '../data/reportData';
import {
  ON_TIME_MINUTES,
  dateRange,
  guestBookings,
  punctuality,
  ridershipByDay,
  ridershipByStop,
  routeSuggestions,
  type ReportRoute,
} from '../lib/reports';

const TABS = [
  { id: 'punctuality', label: 'Punctuality' },
  { id: 'ridership', label: 'Ridership' },
  { id: 'guests', label: 'Guest bookings' },
  { id: 'suggestions', label: 'Route suggestions' },
] as const;
type Tab = (typeof TABS)[number]['id'];

const percent = (x: number | null) => (x === null ? '—' : `${Math.round(x * 100)}%`);
const minutes = (x: number | null) => (x === null ? '—' : `${x > 0 ? '+' : ''}${x} min`);
const shortDate = (d: string) => new Date(`${d}T12:00:00Z`).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', timeZone: 'UTC' });

/** Punctuality, ridership, guest bookings and route suggestions over recent days. */
export function ReportsPage() {
  const [days, setDays] = useState(14);
  const [tab, setTab] = useState<Tab>('punctuality');
  const today = campusToday();
  const { from, to } = dateRange(today, days);
  const data = useReportData(from, to);
  const routesRaw = useRoutes().data;
  const buses = useBuses().data;
  const routes: ReportRoute[] = useMemo(() => routesRaw.slice().sort(byName), [routesRaw]);
  const routeName = (id: string) => routes.find((r) => r.id === id)?.name ?? id;

  return (
    <section className="page">
      <h2>Reports</h2>
      <div className="toolbar">
        <label className="field inline"><span>Period</span>
          <select value={days} onChange={(e) => setDays(Number(e.target.value))}>
            <option value={7}>Last 7 days</option>
            <option value={14}>Last 14 days</option>
            <option value={30}>Last 30 days</option>
          </select>
        </label>
        <span className="muted">{shortDate(from)} to {shortDate(to)} · {data.trips.length} trips</span>
        <button className="ghost" onClick={data.reload} disabled={data.loading}>Refresh</button>
      </div>
      <div className="tabs" role="tablist">
        {TABS.map((t) => (
          <button key={t.id} role="tab" aria-selected={tab === t.id} className={tab === t.id ? 'tab active' : 'tab'} onClick={() => setTab(t.id)}>
            {t.label}
          </button>
        ))}
      </div>
      {data.error && <p className="alert" role="alert">{data.error}</p>}
      {data.loading ? (
        <div className="centered-small" aria-busy="true"><span className="spinner" /></div>
      ) : data.trips.length === 0 && data.bookings.length === 0 ? (
        <p className="muted">No trips recorded in this period.</p>
      ) : (
        <>
          {tab === 'punctuality' && <Punctuality data={data} routes={routes} />}
          {tab === 'ridership' && <Ridership data={data} routes={routes} routeName={routeName} />}
          {tab === 'guests' && <Guests data={data} routes={routes} routeName={routeName} today={today} />}
          {tab === 'suggestions' && (
            <Suggestions data={data} routes={routes} routeName={routeName} capacityOf={(id) => buses.find((b) => b.id === id)?.capacity ?? 0} />
          )}
        </>
      )}
    </section>
  );
}

type Data = ReturnType<typeof useReportData>;

function Punctuality({ data, routes }: { data: Data; routes: ReportRoute[] }) {
  const rows = useMemo(() => punctuality(data.trips, routes), [data.trips, routes]);
  const labels = useMemo(() => rows.map((r) => r.routeName), [rows]);
  const series = useMemo(() => [{ label: 'Average minutes late', values: rows.map((r) => r.averageLateMinutes ?? 0), colour: SERIES_COLOURS[0] }], [rows]);
  return (
    <>
      <p className="muted">Morning trips: arrival at campus against the timetable. On time means no more than {ON_TIME_MINUTES} minutes late.</p>
      <BarChart labels={labels} series={series} yTitle="Minutes late at campus" label="Average minutes late at campus per route" />
      <table className="table">
        <thead><tr><th>Route</th><th>Trips</th><th>Average</th><th>On time</th><th>Worst</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.routeId}>
              <td>{r.routeName}</td><td>{r.trips}</td><td>{minutes(r.averageLateMinutes)}</td>
              <td>{percent(r.onTimeShare)}</td><td>{minutes(r.worstLateMinutes)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

function Ridership({ data, routes, routeName }: { data: Data; routes: ReportRoute[]; routeName: (id: string) => string }) {
  const days = useMemo(() => ridershipByDay(data.trips), [data.trips]);
  const stops = useMemo(() => ridershipByStop(data.trips, routes), [data.trips, routes]);
  const dates = useMemo(() => [...new Set(days.map((d) => d.date))].sort(), [days]);
  const labels = useMemo(() => dates.map(shortDate), [dates]);
  const series = useMemo(
    () => routes.map((r, i) => ({
      label: r.name,
      colour: SERIES_COLOURS[i % SERIES_COLOURS.length],
      values: dates.map((d) => {
        const row = days.find((x) => x.date === d && x.routeId === r.id);
        return row ? row.pass + row.alternate + row.guest : 0;
      }),
    })),
    [routes, dates, days],
  );
  return (
    <>
      <p className="muted">Riders per day, from pass scans and guest tickets, morning and evening.</p>
      <BarChart labels={labels} series={series} stacked yTitle="Riders" label="Riders per day by route" />
      <table className="table">
        <thead><tr><th>Date</th><th>Route</th><th>Pass</th><th>Other route</th><th>Guest</th></tr></thead>
        <tbody>
          {days.map((d) => (
            <tr key={`${d.date}|${d.routeId}`}><td>{shortDate(d.date)}</td><td>{routeName(d.routeId)}</td><td>{d.pass}</td><td>{d.alternate}</td><td>{d.guest}</td></tr>
          ))}
        </tbody>
      </table>
      <h3>Morning riders by stop</h3>
      <table className="table">
        <thead><tr><th>Route</th><th>Stop</th><th>Riders</th><th>Per trip</th></tr></thead>
        <tbody>
          {stops.map((s) => (
            <tr key={`${s.routeId}|${s.stopId}`}><td>{routeName(s.routeId)}</td><td>{s.stopName}</td><td>{s.riders}</td><td>{s.perTrip}</td></tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

function Guests({ data, routes, routeName, today }: { data: Data; routes: ReportRoute[]; routeName: (id: string) => string; today: string }) {
  const rows = useMemo(() => guestBookings(data.bookings, today), [data.bookings, today]);
  const dates = useMemo(() => [...new Set(rows.map((r) => r.date))].sort(), [rows]);
  const labels = useMemo(() => dates.map(shortDate), [dates]);
  const series = useMemo(
    () => routes.map((r, i) => ({
      label: r.name,
      colour: SERIES_COLOURS[i % SERIES_COLOURS.length],
      values: dates.map((d) => rows.find((x) => x.date === d && x.routeId === r.id)?.fares ?? 0),
    })),
    [routes, dates, rows],
  );
  const total = rows.reduce((t, r) => ({ guests: t.guests + r.guests, fares: t.fares + r.fares }), { guests: 0, fares: 0 });
  if (rows.length === 0) return <p className="muted">No paid guest seats in this period.</p>;
  return (
    <>
      <p className="muted">{total.guests} guest seats, ₹{total.fares} collected. A paid seat not scanned is a no-show; the fare is kept.</p>
      <BarChart labels={labels} series={series} stacked yTitle="Fares (₹)" label="Guest fares collected per day by route" />
      <table className="table">
        <thead><tr><th>Date</th><th>Route</th><th>Guests</th><th>Fares</th><th>No-shows</th></tr></thead>
        <tbody>
          {rows.map((r) => (
            <tr key={`${r.date}|${r.routeId}`}><td>{shortDate(r.date)}</td><td>{routeName(r.routeId)}</td><td>{r.guests}</td><td>₹{r.fares}</td><td>{r.noShows}</td></tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

function Suggestions({ data, routes, routeName, capacityOf }: {
  data: Data;
  routes: ReportRoute[];
  routeName: (id: string) => string;
  capacityOf: (busId: string) => number;
}) {
  const s = useMemo(() => routeSuggestions(data.trips, routes, capacityOf), [data.trips, routes, capacityOf]);
  return (
    <>
      <p className="muted">From morning trips, once a route has at least 5 in the period. Suggestions to look into, not decisions.</p>
      <h3>Stops with very few riders</h3>
      {s.quietStops.length === 0 ? <p className="muted">None: every stop has at least one rider per trip on average.</p> : (
        <table className="table">
          <thead><tr><th>Route</th><th>Stop</th><th>Riders per trip</th></tr></thead>
          <tbody>{s.quietStops.map((q) => <tr key={`${q.routeId}|${q.stopId}`}><td>{routeName(q.routeId)}</td><td>{q.stopName}</td><td>{q.perTrip}</td></tr>)}</tbody>
        </table>
      )}
      <h3>Routes that are regularly full</h3>
      {s.fullRoutes.length === 0 ? <p className="muted">None: no route is at 90% of its seats on half its trips.</p> : (
        <table className="table">
          <thead><tr><th>Route</th><th>Trips at 90% or more</th></tr></thead>
          <tbody>{s.fullRoutes.map((f) => <tr key={f.routeId}><td>{routeName(f.routeId)}</td><td>{percent(f.fullShare)} of {f.trips}</td></tr>)}</tbody>
        </table>
      )}
    </>
  );
}
