import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/l10n.dart';
import '../../../routing/routes.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/session.dart';
import '../../eta/ui/arrival_panel.dart';
import '../../live/ui/live_status.dart';
import '../application/alerts_providers.dart';
import '../domain/feed_item.dart';

/// Trip news for the student's route and office announcements. Works even
/// when push notifications are off or denied.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(alertsSeenProvider.notifier).markSeen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final routeId = session is SignedIn ? session.profile?.routeId : null;
    final feed = routeId == null ? const AsyncValue<List<FeedItem>>.data([]) : ref.watch(alertsFeedProvider(routeId));
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alertsTitle),
        actions: [
          IconButton(
            tooltip: l10n.notificationSettingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.studentNotificationSettings),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.startupError)),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.alertsEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _FeedTile(item: items[i], now: now),
              ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item, required this.now});

  final FeedItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final age = now.difference(item.createdAt);
    final when = age.inHours < 1 ? formatAgo(l10n, age) : formatClock(context, item.createdAt);
    final (icon, colour, title, body) = switch (item) {
      TripAlert(kind: TripAlertKind.tripStarted, :final busNumber) =>
        (Icons.play_circle_outline, Colors.green.shade700, l10n.alertTripStarted(busNumber), null),
      TripAlert(kind: TripAlertKind.delay, :final busNumber, :final minutes) =>
        (Icons.schedule, scheme.tertiary, l10n.alertDelay(busNumber, minutes ?? 0), null),
      TripAlert(kind: TripAlertKind.late, :final busNumber) =>
        (Icons.schedule, scheme.tertiary, l10n.alertLate(busNumber), null),
      TripAlert(kind: TripAlertKind.breakdown, :final busNumber) =>
        (Icons.car_crash_outlined, scheme.error, l10n.alertBreakdown(busNumber), null),
      Announcement(:final title, :final body) => (Icons.campaign_outlined, scheme.primary, title, body),
    };
    return ListTile(
      leading: Icon(icon, color: colour),
      title: Text(title),
      subtitle: Text([?body, if (item is Announcement) l10n.announcementLabel, when].join('\n')),
      isThreeLine: body != null,
    );
  }
}
