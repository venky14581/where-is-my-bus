import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../trip/domain/trip_plan.dart';
import '../domain/missed_bus.dart';

abstract interface class MissedBusRepository {
  /// Trips running on [date] (YYYY-MM-DD), every route.
  Stream<List<RunningTrip>> watchRunningTrips(String date);

  /// `routeAccess`: for each route, the routes whose riders it may carry.
  Stream<Map<String, List<String>>> watchRouteAccess();

  /// The student's hold on [tripId], if any.
  Stream<SeatHold?> watchHold({required String tripId, required String uid});

  /// Seats held on [tripId] by riders from other routes, still to board.
  /// For the trip's driver.
  Stream<List<SeatHold>> watchWaitingHolds(String tripId);

  /// Asks the server for a seat on [tripId], boarding at [stopId].
  Future<HoldResult> hold({required String tripId, required String stopId});

  Future<void> cancel(String tripId);
}

class FirebaseMissedBusRepository implements MissedBusRepository {
  FirebaseMissedBusRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<RunningTrip>> watchRunningTrips(String date) => _db
      .collection('trips')
      .where('date', isEqualTo: date)
      .where('status', isEqualTo: 'running')
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              if (doc.data() case {'busId': final String busId, 'routeId': final String routeId})
                RunningTrip(
                  id: doc.id,
                  busId: busId,
                  routeId: routeId,
                  direction: doc.data()['direction'] == TripDirection.fromCampus.name
                      ? TripDirection.fromCampus
                      : TripDirection.toCampus,
                  passHolders: (doc.data()['passHolders'] as num?)?.toInt(),
                  altHeld: (doc.data()['altHeld'] as num?)?.toInt() ?? 0,
                  seatsBooked: (doc.data()['seatsBooked'] as num?)?.toInt() ?? 0,
                  notRiding: (doc.data()['notRiding'] as num?)?.toInt() ?? 0,
                ),
          ]);

  @override
  Stream<Map<String, List<String>>> watchRouteAccess() => _db.collection('routeAccess').snapshots().map((snap) => {
        for (final doc in snap.docs) doc.id: [for (final id in doc.data()['acceptsFrom'] as List? ?? const []) '$id'],
      });

  @override
  Stream<SeatHold?> watchHold({required String tripId, required String uid}) =>
      _db.doc('trips/$tripId/holds/$uid').snapshots().map((snap) => _holdFrom(snap.id, snap.data()));

  @override
  Stream<List<SeatHold>> watchWaitingHolds(String tripId) => _db
      .collection('trips/$tripId/holds')
      .where('status', isEqualTo: HoldStatus.held.name)
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) ?_holdFrom(doc.id, doc.data())]);

  static SeatHold? _holdFrom(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    final status = HoldStatus.values.where((s) => s.name == data['status']).firstOrNull;
    final stopId = data['stopId'];
    if (status == null || stopId is! String) return null;
    return SeatHold(uid: uid, name: data['name'] as String? ?? '', stopId: stopId, status: status);
  }

  HttpsCallable _callable(String name) =>
      _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 15)));

  @override
  Future<HoldResult> hold({required String tripId, required String stopId}) async {
    try {
      final response = await _callable('holdSeat').call<Map<String, dynamic>>({'tripId': tripId, 'stopId': stopId});
      return HoldResult.values.where((r) => r.name == response.data['result']).firstOrNull ?? HoldResult.notRunning;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'internal') return HoldResult.offline;
      rethrow;
    }
  }

  @override
  Future<void> cancel(String tripId) => _callable('cancelHold').call<Map<String, dynamic>>({'tripId': tripId});
}
