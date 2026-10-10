import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../domain/fix.dart';
import '../domain/trip_plan.dart';

class TripStart {
  const TripStart({
    required this.tripId,
    required this.busId,
    required this.routeId,
    required this.driverUid,
    required this.date,
    required this.direction,
  });

  final String tripId;
  final String busId;
  final String routeId;
  final String driverUid;
  final String date;
  final TripDirection direction;
}

abstract interface class TripRepository {
  /// Creates `trips/{tripId}`, or marks it running again when the driver
  /// restarts the same trip. Needs a connection.
  Future<void> startTrip(TripStart start);

  /// The writes below may be queued while offline, so callers do not wait
  /// for them to reach the server.
  Future<void> endTrip(String tripId);

  /// Overwrites `live/{busId}`. Only the latest point is kept.
  Future<void> publishPosition({required String busId, required String tripId, required Fix fix});

  /// Arranges for `live/{busId}` to show `offline` if the phone drops off
  /// the network. Must be repeated after every reconnect, and only once a
  /// position has been written.
  Future<void> armDisconnect(String busId);

  Future<void> markLiveEnded({required String busId, required String tripId});

  Future<void> recordStopArrival({required String tripId, required String stopId, required DateTime at});

  /// Whether the phone can reach the Realtime Database right now.
  Stream<bool> connection();
}

class FirebaseTripRepository implements TripRepository {
  FirebaseTripRepository(this._db, this._rtdb);

  final FirebaseFirestore _db;
  final FirebaseDatabase _rtdb;

  DatabaseReference _live(String busId) => _rtdb.ref('live/$busId');

  @override
  Future<void> startTrip(TripStart start) async {
    final ref = _db.doc('trips/${start.tripId}');
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({'status': 'running', 'endedAt': null});
      return;
    }
    await ref.set({
      'busId': start.busId,
      'routeId': start.routeId,
      'driverId': start.driverUid,
      'date': start.date,
      'direction': start.direction.name,
      'status': 'running',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    });
  }

  @override
  Future<void> endTrip(String tripId) => _db
      .doc('trips/$tripId')
      .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> publishPosition({required String busId, required String tripId, required Fix fix}) =>
      _live(busId).set({
        'lat': fix.lat,
        'lng': fix.lng,
        'speed': fix.speedMps,
        'heading': fix.heading,
        'accuracy': fix.accuracyM,
        // Server time, so "updated 20 seconds ago" is right on every phone
        // whatever its clock says.
        'updatedAt': ServerValue.timestamp,
        'tripId': tripId,
        'status': 'running',
      });

  @override
  Future<void> armDisconnect(String busId) =>
      _live(busId).onDisconnect().update({'status': 'offline'});

  @override
  Future<void> markLiveEnded({required String busId, required String tripId}) async {
    await _live(busId).onDisconnect().cancel();
    await _live(busId).update({'status': 'ended', 'updatedAt': ServerValue.timestamp, 'tripId': tripId});
  }

  @override
  Future<void> recordStopArrival({required String tripId, required String stopId, required DateTime at}) =>
      _db.doc('trips/$tripId/stopTimes/$stopId').set({
        'stopId': stopId,
        // When the bus was there, from the phone. recordedAt shows when the
        // server heard about it, which is later after a dead zone.
        'arrivedAt': Timestamp.fromDate(at),
        'recordedAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<bool> connection() =>
      _rtdb.ref('.info/connected').onValue.map((event) => event.snapshot.value == true);
}
