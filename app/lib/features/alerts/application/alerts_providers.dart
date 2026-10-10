import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/settings_store.dart';
import '../data/alerts_repository.dart';
import '../data/push_service.dart';
import '../domain/feed_item.dart';

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => FirestoreAlertsRepository(FirebaseFirestore.instance, clock: ref.watch(clockProvider)),
);

final pushServiceProvider = Provider<PushService>((ref) => FcmPushService(FirebaseFirestore.instance));

final alertsFeedProvider = StreamProvider.autoDispose.family<List<FeedItem>, String>(
  (ref, routeId) => ref.watch(alertsRepositoryProvider).watchFeed(routeId),
);

/// When the student last opened the alerts list, for the unread badge.
class AlertsSeenController extends Notifier<DateTime?> {
  static const _key = 'alertsSeenAt';

  @override
  DateTime? build() => DateTime.tryParse(ref.read(settingsStoreProvider).read(_key) ?? '');

  Future<void> markSeen() async {
    final now = ref.read(clockProvider)();
    state = now;
    await ref.read(settingsStoreProvider).write(_key, now.toIso8601String());
  }
}

final alertsSeenProvider = NotifierProvider<AlertsSeenController, DateTime?>(AlertsSeenController.new);
