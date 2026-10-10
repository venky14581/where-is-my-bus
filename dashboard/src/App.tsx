import { LoginPage } from './auth/LoginPage';
import { useOfficeSession } from './auth/useOfficeSession';
import { Shell } from './Shell';

export default function App() {
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
