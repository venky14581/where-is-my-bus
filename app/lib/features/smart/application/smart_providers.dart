import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_bootstrap.dart';
import '../../eta/domain/learned_times.dart';
import '../../routes/domain/bus_route.dart';
import '../../trip/domain/trip_plan.dart';
import '../data/smart_repository.dart';

final smartRepositoryProvider = Provider<SmartRepository>(
  (ref) => FirebaseSmartRepository(FirebaseFirestore.instance, FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final learnedTimesProvider = StreamProvider.autoDispose.family<LearnedTimes?, String>(
  (ref, routeId) => ref.watch(smartRepositoryProvider).watchLearned(routeId),
);

final conditionsProvider = StreamProvider.autoDispose.family<Conditions?, String>(
  (ref, date) => ref.watch(smartRepositoryProvider).watchConditions(date),
);

final tripSeatsProvider = StreamProvider.autoDispose.family<TripSeats?, String>(
  (ref, tripId) => ref.watch(smartRepositoryProvider).watchTripSeats(tripId),
);

final notRidingProvider = StreamProvider.autoDispose.family<bool, ({String tripId, String uid})>(
  (ref, key) => ref.watch(smartRepositoryProvider).watchNotRiding(tripId: key.tripId, uid: key.uid),
);

/// Learned times and today's slowness for an estimate on [route] at [now].
TravelModel travelModel(WidgetRef ref, BusRoute route, TripDirection direction, DateTime now) => TravelModel.of(
      learned: ref.watch(learnedTimesProvider(route.id)).value,
      conditions: ref.watch(conditionsProvider(tripDate(now))).value,
      direction: direction,
      at: now,
      stopCount: route.stops.length,
    );
