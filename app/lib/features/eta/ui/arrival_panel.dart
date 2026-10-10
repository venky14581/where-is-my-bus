import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../live/domain/live_bus.dart';
import '../../routes/domain/bus_route.dart';
import '../../smart/application/smart_providers.dart';
import '../../trip/domain/trip_plan.dart';
import '../application/eta_providers.dart';
import '../domain/arrival.dart';
import '../domain/learned_times.dart';

/// Where the bus stands relative to [stopId], or null when there is nothing
/// to estimate (no trip running).
Arrival? arrivalFor({
  required BusRoute route,
  required String stopId,
  required LiveBus? live,
  required DateTime serverNow,
  required Map<String, DateTime> stopTimes,
  TravelModel? travel,
}) {
  if (live == null) return null;
  final state = live.stateAt(serverNow);
  if (state == BusLiveState.notRunning) return null;
  final recorded = stopTimes[stopId];
  // An offline bus's last position is too old to estimate from, but a
  // recorded stop time still says for certain that it has passed.
  if (state == BusLiveState.offline) return recorded == null ? null : Passed(recorded);
  return RouteTimeline.of(route).arrivalAt(
    stopId: stopId,
    busLat: live.lat,
    busLng: live.lng,
    direction: directionOfTrip(live.tripId),
    recordedAt: recorded,
    travel: travel,
  );
}

/// When the bus is expected at the stop. Counts from the last position, not
/// from now, so an estimate does not drift later while updates are delayed.
DateTime expectedAt(Approaching arrival, LiveBus live, DateTime serverNow) {
  final at = live.updatedAt.add(arrival.eta);
  return at.isBefore(serverNow) ? serverNow : at;
}

String formatClock(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time));

/// The headline on the student home: minutes to their stop, at the stop, or
/// passed; and, for a student who gave their walk, when to leave home.
class ArrivalPanel extends ConsumerWidget {
  const ArrivalPanel({
    super.key,
    required this.route,
    required this.stopId,
    required this.live,
    required this.serverNow,
    this.walkMinutes,
  });

  final BusRoute route;
  final String stopId;
  final LiveBus? live;
  final DateTime serverNow;
  final int? walkMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final live = this.live;
    final tripId = live?.tripId;
    final stopTimes = tripId == null ? const <String, DateTime>{} : ref.watch(stopTimesProvider(tripId)).value ?? const {};
    final direction = directionOfTrip(tripId);
    final arrival = arrivalFor(
      route: route,
      stopId: stopId,
      live: live,
      serverNow: serverNow,
      stopTimes: stopTimes,
      travel: travelModel(ref, route, direction, serverNow),
    );
    if (arrival == null || live == null) return const SizedBox.shrink();
    final walk = walkMinutes;
    // Evening riders board at campus; there is no home to leave from.
    final leave = arrival is Approaching && walk != null && direction == TripDirection.toCampus
        ? leaveAt(expectedAt(arrival, live, serverNow), walk)
        : null;

    final stale = live.stateAt(serverNow) == BusLiveState.stale;
    final (headline, detail, colour) = switch (arrival) {
      Approaching() => () {
          final at = expectedAt(arrival, live, serverNow);
          final minutes = (at.difference(serverNow).inSeconds / 60).ceil().clamp(1, 999);
          return (l10n.etaMinutes(minutes), l10n.etaAround(formatClock(context, at)), scheme.primary);
        }(),
      ArrivingNow() => (l10n.arrivingNow, null, Colors.green.shade700),
      Passed(:final at) => (
          at == null ? l10n.passedNoTime : l10n.passedAt(formatClock(context, at)),
          null,
          scheme.error,
        ),
      OffRoute() => (l10n.offRoute, null, scheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: (arrival is OffRoute ? text.bodyLarge : text.headlineSmall)?.copyWith(color: colour),
            ),
            if (detail != null) Text(detail, style: text.titleMedium),
            if (leave != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.directions_walk, size: 20, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        leave.isAfter(serverNow) ? l10n.leaveBy(formatClock(context, leave)) : l10n.leaveNow,
                        style: text.titleMedium?.copyWith(color: scheme.tertiary),
                      ),
                    ),
                  ],
                ),
              ),
            if (stale && arrival is Approaching)
              Text(l10n.etaFromLastPosition, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
