import { useState, type FormEvent } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { FirebaseError } from 'firebase/app';
import { auth } from '../firebase';
import { BusIcon } from '../BusIcon';

const notices = {
  notOffice: 'This account is not a transport office account. Students and drivers use the mobile app.',
  profileError: "Couldn't load your account. Check your connection and try again.",
} as const;

function messageFor(error: unknown): string {
  if (error instanceof FirebaseError) {
    switch (error.code) {
      case 'auth/invalid-credential':
      case 'auth/wrong-password':
      case 'auth/user-not-found':
      case 'auth/invalid-email':
        return 'Email or password is wrong.';
      case 'auth/too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'auth/network-request-failed':
        return 'No connection to the server.';
      case 'auth/user-disabled':
        return 'This account is disabled.';
    }
  }
  return 'Something went wrong. Try again.';
}

export function LoginPage({ notice }: { notice?: keyof typeof notices }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      // useOfficeSession takes over from here and checks the role.
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (e) {
      setError(messageFor(e));
      setBusy(false);
    }
  }

  const shown = error ?? (notice ? notices[notice] : null);

  return (
    <main className="login">
      <form className="login-card" onSubmit={onSubmit} noValidate>
        <div className="brand">
          <span className="brand-badge"><BusIcon /></span>
          <div>
            <h1>Where Is My Bus</h1>
            <p className="muted">Transport office</p>
          </div>
        </div>

        <label className="field">
          <span>Email</span>
          <input
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label className="field">
          <span>Password</span>
          <input
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>

        {shown && <p className="alert" role="alert">{shown}</p>}

        <button className="primary" type="submit" disabled={busy || !email || !password}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}
