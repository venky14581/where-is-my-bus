import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/bus_route.dart';

abstract interface class RouteRepository {
  /// Every active route, sorted by city then name.
  Stream<List<BusRoute>> watchRoutes();

  /// Null when the route no longer exists.
  Stream<BusRoute?> watchRoute(String routeId);

  /// The bus that runs a route, if one is assigned.
  Stream<Bus?> watchBusForRoute(String routeId);

  /// The bus assigned to a driver, by the driver's uid.
  Stream<Bus?> watchBusForDriver(String driverUid);

  /// Saves the student's route and home stop. Security rules refuse a stop
  /// that is not on the route.
  Future<void> saveHomeStop({
    required String uid,
    required String routeId,
    required String stopId,
  });
}

class FirestoreRouteRepository implements RouteRepository {
  FirestoreRouteRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<BusRoute>> watchRoutes() => _db
      .collection('routes')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) BusRoute.fromMap(d.id, d.data())]
        ..sort((a, b) => a.city == b.city ? a.name.compareTo(b.name) : a.city.compareTo(b.city)));

  @override
  Stream<BusRoute?> watchRoute(String routeId) => _db
      .doc('routes/$routeId')
      .snapshots()
      .map((snap) => snap.exists ? BusRoute.fromMap(snap.id, snap.data()!) : null);

  @override
  Stream<Bus?> watchBusForRoute(String routeId) =>
      _firstBus(_db.collection('buses').where('routeId', isEqualTo: routeId));

  @override
  Stream<Bus?> watchBusForDriver(String driverUid) =>
      _firstBus(_db.collection('buses').where('driverId', isEqualTo: driverUid));

  Stream<Bus?> _firstBus(Query<Map<String, dynamic>> query) => query.limit(1).snapshots().map(
        (snap) => snap.docs.isEmpty ? null : Bus.fromMap(snap.docs.first.id, snap.docs.first.data()),
      );

  @override
  Future<void> saveHomeStop({
    required String uid,
    required String routeId,
    required String stopId,
  }) =>
      _db.doc('users/$uid').update({'routeId': routeId, 'stopId': stopId});
}
