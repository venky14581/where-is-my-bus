import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase_bootstrap.dart';

import '../../eta/domain/learned_times.dart';

/// What setNotRiding in functions/src/smart.ts answered.
enum NotRidingResult {
  notRiding,
  riding,

  /// Booking has closed; the choice can no longer change.
  locked,

  /// The seat was sold to a guest and none is left to take back.
  seatTaken,
  notYourBus,
  noPass,

  /// The phone could not reach the server.
  offline,
}

/// Seat counts on one trip, for the crowding level.
class TripSeats {
  const TripSeats({this.passHolders, this.notRiding = 0, this.altHeld = 0, this.seatsBooked = 0});

  /// Null until the trip has counted its pass holders.
  final int? passHolders;
  final int notRiding;
  final int altHeld;
  final int seatsBooked;
}

abstract interface class SmartRepository {
  Stream<LearnedTimes?> watchLearned(String routeId);

  /// How today's buses compare with expectations; [date] is YYYY-MM-DD.
  Stream<Conditions?> watchConditions(String date);

  Stream<TripSeats?> watchTripSeats(String tripId);

  /// Whether the student said they are not riding this evening trip.
  Stream<bool> watchNotRiding({required String tripId, required String uid});

  Future<NotRidingResult> setNotRiding({required String tripId, required bool notRiding});
}

class FirebaseSmartRepository implements SmartRepository {
  FirebaseSmartRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<LearnedTimes?> watchLearned(String routeId) => _db
      .doc('segmentTimes/$routeId')
      .snapshots()
      .map((doc) => doc.exists ? LearnedTimes.fromMap(doc.data()!) : null);

  @override
  Stream<Conditions?> watchConditions(String date) => _db.doc('conditions/$date').snapshots().map((doc) {
        final d = doc.data();
        if (d == null) return null;
        return Conditions(ratioSum: (d['ratioSum'] as num?)?.toDouble() ?? 0, count: (d['count'] as num?)?.toInt() ?? 0);
      });

  @override
  Stream<TripSeats?> watchTripSeats(String tripId) => _db.doc('trips/$tripId').snapshots().map((doc) {
        final d = doc.data();
        if (d == null) return null;
        int count(String key) => (d[key] as num?)?.toInt() ?? 0;
        return TripSeats(
          passHolders: (d['passHolders'] as num?)?.toInt(),
          notRiding: count('notRiding'),
          altHeld: count('altHeld'),
          seatsBooked: count('seatsBooked'),
        );
      });

  @override
  Stream<bool> watchNotRiding({required String tripId, required String uid}) =>
      _db.doc('trips/$tripId/notRiding/$uid').snapshots().map((doc) => doc.exists);

  @override
  Future<NotRidingResult> setNotRiding({required String tripId, required bool notRiding}) async {
    try {
      final response = await _functions
          .httpsCallable('setNotRiding', options: HttpsCallableOptions(timeout: callTimeout(const Duration(seconds: 20))))
          .call<Map<String, dynamic>>({'tripId': tripId, 'notRiding': notRiding});
      return NotRidingResult.values.where((r) => r.name == response.data['result']).firstOrNull ?? NotRidingResult.locked;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'internal') return NotRidingResult.offline;
      rethrow;
    }
  }
}
