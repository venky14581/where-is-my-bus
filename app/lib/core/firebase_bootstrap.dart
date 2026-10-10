import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

// `--dart-define=USE_EMULATORS=true|false` overrides the automatic choice.
const _useEmulatorsOverride = String.fromEnvironment('USE_EMULATORS');

// `--dart-define=EMULATOR_HOST=192.168.1.20` for a physical phone on the
// same Wi-Fi as the computer running the emulators.
const _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

Future<void> initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);

  final useEmulators = _useEmulatorsOverride.isEmpty
      ? options.projectId.startsWith('demo-')
      : _useEmulatorsOverride == 'true';
  if (!useEmulators) return;

  final host = _emulatorHost();
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  debugPrint('Using Firebase emulators on $host');
}

String _emulatorHost() {
  if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
  // The Android emulator reaches the host machine through 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return '127.0.0.1';
}
