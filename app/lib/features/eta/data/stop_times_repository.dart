import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class StopTimesRepository {
  /// When the bus was at each stop on [tripId], by stop ID.
  Stream<Map<String, DateTime>> watch(String tripId);
}

class FirestoreStopTimesRepository implements StopTimesRepository {
  FirestoreStopTimesRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Map<String, DateTime>> watch(String tripId) =>
      _db.collection('trips/$tripId/stopTimes').snapshots().map((snap) => {
            for (final doc in snap.docs)
              if (doc.data()['arrivedAt'] case final Timestamp at) doc.id: at.toDate(),
          });
}
