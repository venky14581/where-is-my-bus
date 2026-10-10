# Transport office dashboard

React + Vite + TypeScript. Office staff sign in with email and password; any
other account is signed straight back out. See the root `README.md` for how to
run it against the Firebase emulators.

```bash
npm install
npm run dev     # http://localhost:5173
npm run build   # type-check and build to dist/
npm run lint
```

To use a real Firebase project instead of the emulators, copy `.env.example`
to `.env.local` and fill in the web app config.
