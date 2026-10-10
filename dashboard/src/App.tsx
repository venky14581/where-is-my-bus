import { useEffect, useState } from 'react';
import { LoginPage } from './auth/LoginPage';
import { useOfficeSession } from './auth/useOfficeSession';
import { Shell } from './Shell';
import { SharePage } from './pages/SharePage';

/** #/share/<token>: a parent's link to one trip. Open to anyone with the link. */
function shareToken(): string | null {
  return /^#\/share\/([\w-]{16,64})$/.exec(window.location.hash)?.[1] ?? null;
}

export default function App() {
  const [token, setToken] = useState(shareToken);
  useEffect(() => {
    const onHash = () => setToken(shareToken());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);
  return token ? <SharePage key={token} token={token} /> : <Office />;
}

function Office() {
  const session = useOfficeSession();

  switch (session.status) {
    case 'loading':
      return <div className="centered" aria-busy="true"><span className="spinner" /></div>;
    case 'signedOut':
      return <LoginPage notice={session.notice} />;
    case 'office':
      return <Shell name={session.name} />;
  }
}
