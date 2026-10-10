import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../routing/routes.dart';
import '../alerts/application/alerts_providers.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';
import '../booking/domain/seats.dart';
import '../eta/domain/learned_times.dart';
import '../eta/ui/arrival_panel.dart';
import '../live/application/live_providers.dart';
import '../live/domain/live_bus.dart';
import '../live/ui/bus_map.dart';
import '../live/ui/live_status.dart';
import '../routes/application/route_providers.dart';
import '../routes/domain/bus_route.dart';
import '../routes/ui/scheduled_time.dart';
import '../smart/application/smart_providers.dart';

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
          ? (profile?.dailyRider == false ? _NoDailyBus(name: profile?.name ?? '') : const SizedBox.shrink())
          : _MyBus(routeId: routeId, stopId: profile?.stopId, name: profile?.name ?? '', walkMinutes: profile?.walkMinutes),
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
  const _MyBus({required this.routeId, required this.stopId, required this.name, required this.walkMinutes});

  final String routeId;
  final String? stopId;
  final String name;
  final int? walkMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider(routeId));
    final bus = ref.watch(routeBusProvider(routeId)).value;
    final live = bus == null ? null : ref.watch(liveBusProvider(bus.id)).value;
    final learned = ref.watch(learnedTimesProvider(routeId)).value;

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
                        ArrivalPanel(route: route, stopId: stop.id, live: live, serverNow: now, walkMinutes: walkMinutes),
                      if (bus == null)
                        Text(context.l10n.noBusOnRoute)
                      else
                        LiveStatusLine(bus: live, serverNow: now),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push(Routes.studentMissedBus),
                            icon: const Icon(Icons.directions_run),
                            label: Text(context.l10n.missedBusButton),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.push(Routes.studentEveningSeats),
                            icon: const Icon(Icons.nights_stay_outlined),
                            label: Text(context.l10n.eveningSeatsButton),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StopCard(
                        route: route,
                        stop: stop,
                        busNumber: bus?.number,
                        weekday: campusClock(now).weekday,
                        usualDelay: learned?.delayByWeekday[campusClock(now).weekday],
                        crowd: switch ((bus, live?.tripId)) {
                          (final bus?, final tripId?) when live!.stateAt(now) != BusLiveState.notRunning =>
                            _crowdOn(ref, tripId, bus.capacity),
                          _ => null,
                        },
                      ),
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

/// How full the running trip is, once it has counted its pass holders.
CrowdLevel? _crowdOn(WidgetRef ref, String tripId, int capacity) {
  final seats = ref.watch(tripSeatsProvider(tripId)).value;
  final passHolders = seats?.passHolders;
  if (seats == null || passHolders == null) return null;
  return crowdLevel(
    capacity: capacity,
    passHolders: passHolders,
    notRiding: seats.notRiding,
    altHeld: seats.altHeld,
    seatsBooked: seats.seatsBooked,
  );
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.route,
    required this.stop,
    required this.busNumber,
    required this.weekday,
    required this.usualDelay,
    required this.crowd,
  });

  final BusRoute route;
  final RouteStop stop;
  final String? busNumber;

  /// Today, as an ISO weekday on the campus clock.
  final int weekday;

  /// How late the bus usually is on [weekday], from past trips.
  final DelayPattern? usualDelay;
  final CrowdLevel? crowd;

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
            if (usualDelay case final usual?)
              Text(() {
                final locale = Localizations.localeOf(context).toLanguageTag();
                // 5 Oct 2026 was a Monday; day d of that week has ISO weekday d.
                final today = DateFormat.EEEE(locale).format(DateTime(2026, 10, 4 + weekday));
                return usual.minutes < 2 ? l10n.usualDelayOnTime(today) : l10n.usualDelayLate(usual.minutes, today);
              }()),
            if (crowd case final crowd?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(crowd == CrowdLevel.standingOnly ? Icons.people : Icons.event_seat_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(switch (crowd) {
                      CrowdLevel.seatsAvailable => l10n.crowdSeats,
                      CrowdLevel.fewSeats => l10n.crowdFew,
                      CrowdLevel.standingOnly => l10n.crowdStanding,
                    }),
                  ],
                ),
              ),
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

/// Hostellers and students with their own transport: no bus to follow,
/// evening seats to book.
class _NoDailyBus extends StatelessWidget {
  const _NoDailyBus({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.helloName(name), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(l10n.noDailyBusHome, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.push(Routes.studentEveningSeats),
          icon: const Icon(Icons.nights_stay_outlined),
          label: Text(l10n.eveningSeatsButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(Routes.studentChooseRoute),
          child: Text(l10n.chooseDailyRouteButton),
        ),
      ],
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
