import 'package:firebase_database/firebase_database.dart';

import '../domain/live_bus.dart';

abstract interface class LiveRepository {
  /// Null when the bus has never sent a position.
  Stream<LiveBus?> watchBus(String busId);

  /// Every bus that has a position, running or not.
  Stream<List<LiveBus>> watchAll();

  /// How far the phone's clock is from the server's, so "updated 20 s ago"
  /// is right even on a phone with the wrong time.
  Stream<Duration> serverTimeOffset();
}

class FirebaseLiveRepository implements LiveRepository {
  FirebaseLiveRepository(this._db);

  final FirebaseDatabase _db;

  @override
  Stream<LiveBus?> watchBus(String busId) =>
      _db.ref('live/$busId').onValue.map((event) => LiveBus.tryFromMap(busId, event.snapshot.value));

  @override
  Stream<List<LiveBus>> watchAll() => _db.ref('live').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <LiveBus>[];
        return [
          for (final entry in value.entries) ?LiveBus.tryFromMap('${entry.key}', entry.value),
        ];
      });

  @override
  Stream<Duration> serverTimeOffset() => _db
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => Duration(milliseconds: (event.snapshot.value as num? ?? 0).round()));
}
