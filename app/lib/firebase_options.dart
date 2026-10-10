import 'package:firebase_core/firebase_core.dart';

/// Placeholder options for the local Firebase Emulator Suite.
///
/// Projects whose ID starts with `demo-` never reach real Firebase, so these
/// values are safe to commit. To connect a real project, run
/// `flutterfire configure` in `app/`; it overwrites this file, and
/// `firebase_bootstrap.dart` then stops using the emulators automatically.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => demo;

  static const demo = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-whereismybus',
    authDomain: 'demo-whereismybus.firebaseapp.com',
    // The emulator applies database.rules.json only to the default instance,
    // which is named <projectId>-default-rtdb, as in production.
    databaseURL: 'http://127.0.0.1:9000/?ns=demo-whereismybus-default-rtdb',
  );
}
