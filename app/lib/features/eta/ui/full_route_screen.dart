import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/session.dart';
import '../../live/application/live_providers.dart';
import '../../live/domain/live_bus.dart';
import '../../live/ui/live_status.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/bus_route.dart';
import '../../routes/ui/scheduled_time.dart';
import '../../trip/domain/trip_plan.dart';
import '../application/eta_providers.dart';
import '../domain/arrival.dart';
import 'arrival_panel.dart';

/// Every stop in travel order: when it was passed, or when the bus is
/// expected there.
class FullRouteScreen extends ConsumerWidget {
  const FullRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    final routeId = profile?.routeId;
    final route = routeId == null ? null : ref.watch(routeProvider(routeId)).value;
    final bus = routeId == null ? null : ref.watch(routeBusProvider(routeId)).value;
    final live = bus == null ? null : ref.watch(liveBusProvider(bus.id)).value;
    final tripId = live?.tripId;
    final stopTimes = tripId == null ? const <String, DateTime>{} : ref.watch(stopTimesProvider(tripId)).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fullRouteTitle)),
      body: route == null
          ? const Center(child: CircularProgressIndicator())
          : ServerClock(
              builder: (context, now) => _StopList(
                route: route,
                homeStopId: profile?.stopId,
                live: live,
                stopTimes: stopTimes,
                now: now,
              ),
            ),
    );
  }
}

class _StopList extends StatelessWidget {
  const _StopList({
    required this.route,
    required this.homeStopId,
    required this.live,
    required this.stopTimes,
    required this.now,
  });

  final BusRoute route;
  final String? homeStopId;
  final LiveBus? live;
  final Map<String, DateTime> stopTimes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final live = this.live;
    final running = live != null && live.stateAt(now) != BusLiveState.notRunning;
    final direction = running ? directionOfTrip(live.tripId) : directionAt(now);
    final stops = stopsInTravelOrder(route, direction);
    // The timetable holds morning times; they mean nothing on the way home.
    final showSchedule = direction == TripDirection.toCampus;

    final rows = <Widget>[
      if (running)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: LiveStatusLine(bus: live, serverNow: now),
        ),
    ];
    var busShown = !running;
    for (final stop in stops) {
      final arrival = arrivalFor(route: route, stopId: stop.id, live: live, serverNow: now, stopTimes: stopTimes);
      if (!busShown && arrival is! Passed) {
        rows.add(_BusHereRow(label: l10n.busIsHere));
        busShown = true;
      }
      rows.add(_StopRow(
        stop: stop,
        isHome: stop.id == homeStopId,
        status: _statusFor(context, stop, arrival, showSchedule),
        passed: arrival is Passed,
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }

  String _statusFor(BuildContext context, RouteStop stop, Arrival? arrival, bool showSchedule) {
    final l10n = context.l10n;
    final scheduled = showSchedule ? l10n.stopScheduled(formatScheduledTime(context, stop.scheduledTime)) : null;
    final live = this.live;
    final status = switch (arrival) {
      Passed(:final at) => at == null ? l10n.stopPassed : l10n.stopPassedAt(formatClock(context, at)),
      ArrivingNow() => l10n.busIsHere,
      Approaching() when live != null => l10n.stopExpected(formatClock(context, expectedAt(arrival, live, now))),
      _ => null,
    };
    return [?status, ?scheduled].join(' · ');
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isHome, required this.status, required this.passed});

  final RouteStop stop;
  final bool isHome;
  final String status;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = passed ? scheme.onSurfaceVariant : null;
    return ListTile(
      leading: Icon(
        isHome ? Icons.location_on : (passed ? Icons.check_circle_outline : Icons.radio_button_unchecked),
        color: isHome ? scheme.tertiary : muted,
      ),
      title: Text(
        stop.name,
        style: TextStyle(fontWeight: isHome ? FontWeight.bold : null, color: muted),
      ),
      subtitle: status.isEmpty ? null : Text(status),
      trailing: isHome ? Text(context.l10n.yourStopTitle) : null,
    );
  }
}

class _BusHereRow extends StatelessWidget {
  const _BusHereRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
