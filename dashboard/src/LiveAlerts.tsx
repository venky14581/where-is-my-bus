import { useEffect, useRef, useState } from 'react';
import { Timestamp, collection, limit, orderBy, query, where } from 'firebase/firestore';
import { db } from './firebase';
import { useQuery } from './data/hooks';
import { useOpenAlertsLive } from './data/safetyAlerts';
import { feedSince, takeNew, toastForFeed, toastForSafety, type OfficeToast } from './lib/liveAlerts';

/**
 * Pops up what happens while the office has the dashboard open (SOS, safety
 * alerts, drivers' reports, trips starting), with a sound and, once allowed,
 * a desktop notification so it is seen even in another tab.
 */
export function LiveAlerts() {
  const [openedAt] = useState(() => Date.now());
  const openAlerts = useOpenAlertsLive();
  const safety = openAlerts.data;
  const feed = useQuery(
    query(collection(db, 'alerts'), where('createdAt', '>', Timestamp.fromMillis(openedAt)), orderBy('createdAt', 'desc'), limit(20)),
    (id, d) => ({ id, data: d, createdAt: d.createdAt }),
    `office-feed-${openedAt}`,
  ).data;

  const [toasts, setToasts] = useState<OfficeToast[]>([]);
  const [muted, setMuted] = useState(false);
  const [permission, setPermission] = useState(() => (typeof Notification === 'undefined' ? 'denied' : Notification.permission));
  const seen = useRef(new Set<string>());
  const safetyPrimed = useRef(false);
  const mutedRef = useRef(muted);
  useEffect(() => {
    mutedRef.current = muted;
  }, [muted]);

  function announce(fresh: OfficeToast[]) {
    if (fresh.length === 0) return;
    setToasts((t) => [...fresh, ...t].slice(0, 6));
    if (!mutedRef.current) chime(fresh.some((t) => t.tone === 'danger') ? 'urgent' : 'notice');
    if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
      for (const t of fresh) new Notification(`Where Is My Bus: ${t.title}`, { body: t.body, tag: t.id });
    }
  }

  // Safety alerts already open when the page loads are in the banner; only
  // new ones pop up.
  useEffect(() => {
    // Wait for the first real answer: until then "none open" means "not
    // loaded yet", and everything after it would look new.
    if (openAlerts.loading) return;
    const ids = safety.map((a) => `safety:${a.id}`);
    if (!safetyPrimed.current) {
      safetyPrimed.current = true;
      takeNew(seen.current, ids);
      return;
    }
    const fresh = new Set(takeNew(seen.current, ids));
    announce(safety.filter((a) => fresh.has(`safety:${a.id}`)).map(toastForSafety));
  }, [safety, openAlerts.loading]);

  useEffect(() => {
    const ids = takeNew(seen.current, feedSince(feed, openedAt).map((id) => `feed:${id}`));
    const byId = new Map(feed.map((f) => [`feed:${f.id}`, f]));
    announce(ids.map((id) => toastForFeed(byId.get(id)!.id, byId.get(id)!.data)).filter((t): t is OfficeToast => t !== null));
  }, [feed, openedAt]);

  // Ordinary pop-ups fade after 12 s; SOS and breakdowns stay.
  useEffect(() => {
    if (!toasts.some((t) => !t.sticky)) return;
    const timer = setTimeout(() => setToasts((t) => t.filter((x) => x.sticky)), 12_000);
    return () => clearTimeout(timer);
  }, [toasts]);

  // An open SOS keeps sounding every 10 s until it is silenced or handled.
  const sosOpen = safety.some((a) => a.type === 'sos');
  useEffect(() => {
    if (!sosOpen || muted) return;
    const timer = setInterval(() => chime('urgent'), 10_000);
    return () => clearInterval(timer);
  }, [sosOpen, muted]);

  return (
    <>
      <div className="alert-controls">
        <button className="ghost" onClick={() => setMuted((m) => !m)} aria-pressed={muted}>
          {muted ? '🔕 Sound off' : '🔔 Sound on'}
        </button>
        {permission === 'default' && (
          <button className="ghost" onClick={() => Notification.requestPermission().then(setPermission)}>
            Turn on desktop alerts
          </button>
        )}
      </div>
      <div className="toasts" role="region" aria-live="assertive" aria-label="Live alerts">
        {toasts.map((t) => (
          <div key={t.id} className={`toast toast-${t.tone}`} role="alert">
            <div className="toast-text">
              <strong>{t.title}</strong>
              <span>{t.body}</span>
              <a href={t.link} onClick={() => setToasts((all) => all.filter((x) => x.id !== t.id))}>View</a>
            </div>
            <button className="toast-close" aria-label="Dismiss" onClick={() => setToasts((all) => all.filter((x) => x.id !== t.id))}>×</button>
          </div>
        ))}
      </div>
    </>
  );
}

let audio: AudioContext | null = null;

/** A short tone: two notes for news, three sharp beeps for an emergency. */
function chime(kind: 'urgent' | 'notice') {
  try {
    audio ??= new AudioContext();
    if (audio.state === 'suspended') void audio.resume();
    const notes = kind === 'urgent' ? [988, 988, 988] : [660, 880];
    notes.forEach((freq, i) => {
      const osc = audio!.createOscillator();
      const gain = audio!.createGain();
      const start = audio!.currentTime + i * 0.22;
      osc.type = kind === 'urgent' ? 'square' : 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(kind === 'urgent' ? 0.25 : 0.15, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.18);
      osc.connect(gain).connect(audio!.destination);
      osc.start(start);
      osc.stop(start + 0.2);
    });
  } catch {
    // No sound available; the pop-up still shows.
  }
}
