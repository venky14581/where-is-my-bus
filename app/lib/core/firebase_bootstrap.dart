import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

// `--dart-define=USE_EMULATORS=true|false` overrides the automatic choice.
const _useEmulatorsOverride = String.fromEnvironment('USE_EMULATORS');

// `--dart-define=EMULATOR_HOST=192.168.1.20` for a physical phone on the
// same Wi-Fi as the computer running the emulators, or
// `--dart-define=EMULATOR_HOST=127.0.0.1` for a phone on USB after
// `adb reverse tcp:<port> tcp:<port>` for ports 9099, 8080, 9000 and 5001.
const _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

/// Same region as functions/src/app.ts.
const functionsRegion = 'asia-south1';

/// The Auth emulator's address, e.g. `http://127.0.0.1:9099`, while the app
/// runs against the emulators; null on a real project. The emulator sends no
/// email, so sign-up uses it to verify a new student in test mode.
String? authEmulatorOrigin;

Future<void> initFirebase() async {
  var options = DefaultFirebaseOptions.currentPlatform;
  final useEmulators = _useEmulatorsOverride.isEmpty
      ? options.projectId.startsWith('demo-')
      : _useEmulatorsOverride == 'true';
  final host = _emulatorHost();
  final native = !kIsWeb;
  if (useEmulators && native) {
    // On Android and iOS the Realtime Database is pointed at the emulator
    // through its URL alone. Calling useDatabaseEmulator as well makes the
    // Android SDK throw "Cannot call useEmulator() after instance has
    // already been initialized" on every write once the database is in use,
    // so the bus position never reaches the server.
    options = options.copyWith(databaseURL: 'http://$host:9000/?ns=${options.projectId}-default-rtdb');
  }
  await Firebase.initializeApp(options: options);
  if (!useEmulators) return;

  // On Android the Firebase plugins turn 127.0.0.1 into 10.0.2.2 (the
  // Android emulator's way to the computer). A host given on purpose, such
  // as 127.0.0.1 for a phone on USB with `adb reverse`, must be kept as is.
  final map = _emulatorHostOverride.isEmpty;
  await FirebaseAuth.instance.useAuthEmulator(host, 9099, automaticHostMapping: map);
  authEmulatorOrigin = 'http://${!map ? host : _mappedForAuth(host)}:9099';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080, automaticHostMapping: map);
  if (!native) FirebaseDatabase.instance.useDatabaseEmulator(host, 9000, automaticHostMapping: map);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(host, 5001, automaticHostMapping: map);
  debugPrint('Using Firebase emulators on $host');
}

/// Where the Auth plugin really connects: on Android it maps 127.0.0.1 and
/// localhost to the Android emulator's 10.0.2.2.
String _mappedForAuth(String host) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android && (host == '127.0.0.1' || host == 'localhost')
        ? '10.0.2.2'
        : host;

String _emulatorHost() {
  if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
  // The Android emulator reaches the host machine through 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return '127.0.0.1';
}
