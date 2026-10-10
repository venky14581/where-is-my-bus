import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/route_repository.dart';
import '../domain/bus_route.dart';

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => FirestoreRouteRepository(FirebaseFirestore.instance),
);

// Auto-dispose so listeners stop when the screens that need them close,
// including on sign-out, when the rules would start refusing them.

final routesProvider = StreamProvider.autoDispose<List<BusRoute>>(
  (ref) => ref.watch(routeRepositoryProvider).watchRoutes(),
);

final routeProvider = StreamProvider.autoDispose.family<BusRoute?, String>(
  (ref, routeId) => ref.watch(routeRepositoryProvider).watchRoute(routeId),
);

final routeBusProvider = StreamProvider.autoDispose.family<Bus?, String>(
  (ref, routeId) => ref.watch(routeRepositoryProvider).watchBusForRoute(routeId),
);

final driverBusProvider = StreamProvider.autoDispose.family<Bus?, String>(
  (ref, driverUid) => ref.watch(routeRepositoryProvider).watchBusForDriver(driverUid),
);
