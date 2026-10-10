import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/live_repository.dart';
import '../domain/live_bus.dart';

final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => FirebaseLiveRepository(FirebaseDatabase.instance),
);

final liveBusProvider = StreamProvider.autoDispose.family<LiveBus?, String>(
  (ref, busId) => ref.watch(liveRepositoryProvider).watchBus(busId),
);

final allLiveBusesProvider = StreamProvider.autoDispose<List<LiveBus>>(
  (ref) => ref.watch(liveRepositoryProvider).watchAll(),
);

final serverTimeOffsetProvider = StreamProvider.autoDispose<Duration>(
  (ref) => ref.watch(liveRepositoryProvider).serverTimeOffset(),
);

/// Whether the map loads OpenStreetMap tiles. Off in widget tests, which
/// have no network.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
