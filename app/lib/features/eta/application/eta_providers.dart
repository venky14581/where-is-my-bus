import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stop_times_repository.dart';

final stopTimesRepositoryProvider = Provider<StopTimesRepository>(
  (ref) => FirestoreStopTimesRepository(FirebaseFirestore.instance),
);

/// Actual times at each stop for one trip. Empty until the first stop.
final stopTimesProvider = StreamProvider.autoDispose.family<Map<String, DateTime>, String>(
  (ref, tripId) => ref.watch(stopTimesRepositoryProvider).watch(tripId),
);
