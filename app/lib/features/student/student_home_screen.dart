import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../routing/routes.dart';
import '../alerts/application/alerts_providers.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';
import '../eta/ui/arrival_panel.dart';
import '../live/application/live_providers.dart';
import '../live/ui/bus_map.dart';
import '../live/ui/live_status.dart';
import '../routes/application/route_providers.dart';
import '../routes/domain/bus_route.dart';
import '../routes/ui/scheduled_time.dart';

/// Opens on the student's own bus: where it is, and how fresh that is.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    final routeId = profile?.routeId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.myPassTitle,
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.push(Routes.studentPass),
          ),
          if (routeId != null) _AlertsButton(routeId: routeId),
          IconButton(
            tooltip: l10n.allBusesTitle,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Routes.studentAllBuses),
          ),
          const AccountMenu(),
        ],
      ),
      body: routeId == null
          ? const SizedBox.shrink()
          : _MyBus(routeId: routeId, stopId: profile?.stopId, name: profile?.name ?? ''),
    );
  }
}

/// Bell with a dot when something arrived since the list was last opened.
class _AlertsButton extends ConsumerWidget {
  const _AlertsButton({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(alertsFeedProvider(routeId)).value ?? const [];
    final seen = ref.watch(alertsSeenProvider);
    final unread = items.where((i) => seen == null || i.createdAt.isAfter(seen)).length;
    return IconButton(
      tooltip: context.l10n.alertsTitle,
      onPressed: () => context.push(Routes.studentAlerts),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _MyBus extends ConsumerWidget {
  const _MyBus({required this.routeId, required this.stopId, required this.name});

  final String routeId;
  final String? stopId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider(routeId));
    final bus = ref.watch(routeBusProvider(routeId)).value;
    final live = bus == null ? null : ref.watch(liveBusProvider(bus.id)).value;

    return route.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(context.l10n.startupError)),
      data: (route) {
        final stop = route?.stopById(stopId);
        if (route == null || stop == null) return _RouteMissing(name: name);
        return ServerClock(
          builder: (context, now) => LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.55,
                  child: BusMap(
                    route: route,
                    homeStopId: stop.id,
                    followBusId: bus?.id,
                    buses: [
                      if (bus != null && live != null)
                        MapBus(live: live, state: live.stateAt(now), label: bus.number),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      if (bus != null)
                        ArrivalPanel(route: route, stopId: stop.id, live: live, serverNow: now),
                      if (bus == null)
                        Text(context.l10n.noBusOnRoute)
                      else
                        LiveStatusLine(bus: live, serverNow: now),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(Routes.studentMissedBus),
                          icon: const Icon(Icons.directions_run),
                          label: Text(context.l10n.missedBusButton),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StopCard(route: route, stop: stop, busNumber: bus?.number),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.route, required this.stop, required this.busNumber});

  final BusRoute route;
  final RouteStop stop;
  final String? busNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.yourStopTitle, style: text.labelLarge)),
                TextButton(
                  onPressed: () => context.push(Routes.studentChooseRoute),
                  child: Text(l10n.changeButton),
                ),
              ],
            ),
            Text(stop.name, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(route.name),
            if (busNumber != null) Text(l10n.busNumber(busNumber!)),
            const SizedBox(height: 8),
            Text(l10n.busDueAt(formatScheduledTime(context, stop.scheduledTime)), style: text.titleMedium),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push(Routes.studentFullRoute),
                icon: const Icon(Icons.format_list_bulleted),
                label: Text(l10n.fullRouteButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMissing extends StatelessWidget {
  const _RouteMissing({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.helloName(name), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        // The office removed the route or the stop since it was chosen.
        Text(l10n.routeMissing),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.push(Routes.studentChooseRoute),
          child: Text(l10n.chooseRouteButton),
        ),
      ],
    );
  }
}
