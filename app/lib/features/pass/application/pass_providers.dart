import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/firebase_bootstrap.dart';
import '../data/pass_repository.dart';

final passRepositoryProvider = Provider<PassRepository>(
  (ref) => FirebasePassRepository(FirebaseFirestore.instance, FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final passSecretProvider = StreamProvider.autoDispose.family<String?, String>(
  (ref, uid) => ref.watch(passRepositoryProvider).watchSecret(uid),
);

final boardedCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, tripId) => ref.watch(passRepositoryProvider).watchBoardedCount(tripId),
);

/// Builds the camera view that reports QR codes. Tests swap in a fake that
/// reports codes without a camera.
typedef ScannerBuilder = Widget Function(BuildContext context, void Function(String code) onCode);

final scannerBuilderProvider = Provider<ScannerBuilder>(
  (ref) => (context, onCode) => MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value != null) onCode(value);
        },
      ),
);
