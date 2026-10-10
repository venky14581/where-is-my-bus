import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// What the server decided about a scanned code. See scanPass in
/// functions/src/boarding.ts.
enum ScanResult {
  boarded,
  alreadyBoarded,
  notAPass,
  invalidCode,
  expiredCode,
  noPass,
  passExpired,
  wrongRoute,

  /// The phone could not reach the server.
  offline,
}

class ScanOutcome {
  const ScanOutcome(this.result, {this.name = ''});

  final ScanResult result;
  final String name;

  bool get ok => result == ScanResult.boarded || result == ScanResult.alreadyBoarded;
}

abstract interface class PassRepository {
  /// The secret behind the student's rotating QR, once the office has
  /// issued a pass. Cached by Firestore, so it works offline afterwards.
  Stream<String?> watchSecret(String uid);

  /// Asks the server to check a scanned code and record the boarding.
  Future<ScanOutcome> scan({required String tripId, required String code});

  /// How many students have boarded this trip.
  Stream<int> watchBoardedCount(String tripId);
}

class FirebasePassRepository implements PassRepository {
  FirebasePassRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<String?> watchSecret(String uid) =>
      _db.doc('passSecrets/$uid').snapshots().map((snap) => snap.data()?['secret'] as String?);

  @override
  Future<ScanOutcome> scan({required String tripId, required String code}) async {
    try {
      final response = await _functions
          .httpsCallable('scanPass', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
          .call<Map<String, dynamic>>({'tripId': tripId, 'code': code});
      final data = response.data;
      final result = ScanResult.values.where((r) => r.name == data['result']).firstOrNull;
      return ScanOutcome(result ?? ScanResult.invalidCode, name: data['name'] as String? ?? '');
    } on FirebaseFunctionsException catch (e) {
      // Network trouble shows up as unavailable or deadline-exceeded.
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'internal') {
        return const ScanOutcome(ScanResult.offline);
      }
      rethrow;
    }
  }

  @override
  Stream<int> watchBoardedCount(String tripId) =>
      _db.collection('trips/$tripId/boardings').snapshots().map((snap) => snap.size);
}
