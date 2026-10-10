import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/alert_prefs.dart';
import '../domain/feed_item.dart';

abstract interface class AlertsRepository {
  /// Trip alerts for [routeId] from the last day, and announcements for that
  /// route or for everyone from the last week. Newest first.
  Stream<List<FeedItem>> watchFeed(String routeId);

  Future<void> savePrefs(String uid, AlertPrefs prefs);
}

class FirestoreAlertsRepository implements AlertsRepository {
  FirestoreAlertsRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  @override
  Stream<List<FeedItem>> watchFeed(String routeId) {
    final now = _clock();
    final alerts = _db
        .collection('alerts')
        .where('routeId', isEqualTo: routeId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(days: 1))))
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs)
                ?TripAlert.tryFromMap(d.id, d.data(), (d.data()['createdAt'] as Timestamp?)?.toDate()),
            ]);
    final weekAgo = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    Stream<List<FeedItem>> announcementsFor(String? route) => _db
        .collection('announcements')
        .where('routeId', isEqualTo: route)
        .where('createdAt', isGreaterThan: weekAgo)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs)
                if ((d.data()['createdAt'] as Timestamp?)?.toDate() case final at?)
                  Announcement(
                    id: d.id,
                    createdAt: at,
                    title: d.data()['title'] as String? ?? '',
                    body: d.data()['body'] as String? ?? '',
                  ),
            ]);
    return _combineLatest([alerts, announcementsFor(routeId), announcementsFor(null)])
        .map((lists) => [for (final l in lists) ...l]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<void> savePrefs(String uid, AlertPrefs prefs) => _db.doc('users/$uid').update({'alerts': prefs.toMap()});
}

/// Emits the latest list from every stream once each has emitted.
Stream<List<List<FeedItem>>> _combineLatest(List<Stream<List<FeedItem>>> streams) {
  late final StreamController<List<List<FeedItem>>> controller;
  final latest = List<List<FeedItem>?>.filled(streams.length, null);
  final subs = <StreamSubscription<List<FeedItem>>>[];
  controller = StreamController(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(streams[i].listen((value) {
          latest[i] = value;
          if (latest.every((l) => l != null)) controller.add([for (final l in latest) l!]);
        }, onError: controller.addError));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}
