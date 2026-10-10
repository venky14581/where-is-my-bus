import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/session.dart';
import '../../eta/application/eta_providers.dart';
import '../../eta/ui/arrival_panel.dart';
import '../../live/application/live_providers.dart';
import '../../live/domain/live_bus.dart';
import '../../live/ui/bus_map.dart';
import '../../live/ui/live_status.dart';
import '../../pass/ui/pass_screen.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/bus_route.dart';
import '../../trip/domain/trip_plan.dart';
import '../application/missed_bus_providers.dart';
import '../domain/missed_bus.dart';

String formatWalk(AppLocalizations l10n, double metres) => metres < 1000
    ? l10n.distanceMetres((metres / 50).round() * 50)
    : l10n.distanceKm((metres / 1000).toStringAsFixed(1));

/// Missed the bus: other college buses the office allows this student on,
/// where to get on, whether they can make it, and a seat to hold.
class MissedBusScreen extends ConsumerWidget {
  const MissedBusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final user = session is SignedIn ? session.profile : null;
    final today = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.missedBusTitle)),
      body: user == null || user.routeId == null
          ? const SizedBox.shrink()
          : passStatusOf(user, today) != PassStatus.valid
              ? _Note(icon: Icons.badge_outlined, text: l10n.missedBusNeedsPass)
              : ServerClock(builder: (context, now) => _Options(user: user, serverNow: now)),
    );
  }
}

class _Options extends ConsumerStatefulWidget {
  const _Options({required this.user, required this.serverNow});

  final AppUser user;
  final DateTime serverNow;

  @override
  ConsumerState<_Options> createState() => _OptionsState();
}

class _OptionsState extends ConsumerState<_Options> {
  String? _selectedTripId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = widget.user;
    final date = tripDate(ref.watch(clockProvider)());
    final trips = ref.watch(runningTripsProvider(date));
    final access = ref.watch(routeAccessProvider).value ?? const {};
    final routes = {for (final r in ref.watch(routesProvider).value ?? const <BusRoute>[]) r.id: r};
    final buses = {for (final b in ref.watch(busesProvider).value ?? const <Bus>[]) b.id: b};
    final live = {for (final l in ref.watch(allLiveBusesProvider).value ?? const <LiveBus>[]) l.busId: l};
    final here = ref.watch(studentHereProvider);
    final homeStop = routes[user.routeId]?.stopById(user.stopId);

    if (trips.isLoading || routes.isEmpty) return const Center(child: CircularProgressIndicator());

    final allowed = [
      for (final t in trips.value ?? const <RunningTrip>[])
        if (MissedBus.mayRide(tripRouteId: t.routeId, studentRouteId: user.routeId, acceptsFrom: access)) t,
    ];
    final holds = {
      for (final t in allowed)
t.id: ?ref.watch(seatHoldProvider((tripId: t.id, uid: user.uid))).value,
    };
    final stopTimes = {for (final t in allowed) t.id: ref.watch(stopTimesProvider(t.id)).value ?? const <String, DateTime>{}};

    final from = here.value;
    final fromLat = from?.latitude ?? homeStop?.lat;
    final fromLng = from?.longitude ?? homeStop?.lng;
    final options = fromLat == null || fromLng == null
        ? const <RideOption>[]
        : MissedBus.options(
            studentRouteId: user.routeId,
            trips: allowed,
            acceptsFrom: access,
            routes: routes,
            buses: buses,
            live: live,
            stopTimes: stopTimes,
            fromLat: fromLat,
            fromLng: fromLng,
            serverNow: widget.serverNow,
            heldStops: {
              for (final e in holds.entries)
                if (e.value.status == HoldStatus.held) e.key: e.value.stopId,
            },
          );
    final heldTrip = holds.entries.where((e) => e.value.status == HoldStatus.held).firstOrNull?.key;
    final selected = options.where((o) => o.trip.id == (_selectedTripId ?? heldTrip)).firstOrNull ?? options.firstOrNull;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (selected != null)
            SizedBox(
              height: constraints.maxHeight * 0.4,
              child: BusMap(
                key: ValueKey(selected.trip.id),
                route: selected.route,
                homeStopId: selected.pickup.id,
                followBusId: selected.bus.id,
                buses: [
                  MapBus(live: selected.live, state: selected.live.stateAt(widget.serverNow), label: selected.bus.number),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text(l10n.missedBusIntro, style: text.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  here.isLoading
                      ? l10n.missedBusLocating
                      : from != null
                          ? l10n.missedBusFromHere
                          : l10n.missedBusFromStop(homeStop?.name ?? ''),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                if (options.isEmpty) ...[
                  Text(l10n.missedBusNone, style: text.titleMedium),
                  const SizedBox(height: 8),
                  Text(l10n.missedBusNoneHint),
                ],
                for (final option in options)
                  _OptionCard(
                    option: option,
                    hold: holds[option.trip.id],
                    selected: option == selected,
                    serverNow: widget.serverNow,
                    onSelect: () => setState(() => _selectedTripId = option.trip.id),
                  ),
                // A seat released earlier still deserves an explanation.
                for (final e in holds.entries)
                  if (e.value.status == HoldStatus.missed && !options.any((o) => o.trip.id == e.key))
                    _Note(
                      icon: Icons.info_outline,
                      text: l10n.holdMissed(
                        routes[allowed.firstWhere((t) => t.id == e.key).routeId]?.stopById(e.value.stopId)?.name ?? '',
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends ConsumerStatefulWidget {
  const _OptionCard({
    required this.option,
    required this.hold,
    required this.selected,
    required this.serverNow,
    required this.onSelect,
  });

  final RideOption option;
  final SeatHold? hold;
  final bool selected;
  final DateTime serverNow;
  final VoidCallback onSelect;

  @override
  ConsumerState<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends ConsumerState<_OptionCard> {
  bool _busy = false;
  String? _message;

  Future<void> _hold() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    final option = widget.option;
    final result = await ref.read(missedBusRepositoryProvider).hold(tripId: option.trip.id, stopId: option.pickup.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (result) {
        HoldResult.held => null,
        HoldResult.full => l10n.holdFull,
        HoldResult.passed || HoldResult.badStop => l10n.holdPassed,
        HoldResult.notAllowed => l10n.holdNotAllowed,
        HoldResult.noPass => l10n.missedBusNeedsPass,
        HoldResult.notRunning => l10n.holdNotRunning,
        HoldResult.offline => l10n.holdOffline,
      };
    });
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(missedBusRepositoryProvider).cancel(widget.option.trip.id);
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.holdOffline);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final option = widget.option;
    final hold = widget.hold;
    final held = hold?.status == HoldStatus.held;
    final boarded = hold?.status == HoldStatus.boarded;
    final at = widget.serverNow.add(option.busEta);
    final minutes = (option.busEta.inSeconds / 60).ceil();
    final walkMinutes = (option.walkTime.inSeconds / 60).ceil().clamp(1, 999);
    final seats = option.freeSeats;

    return Card.outlined(
      color: widget.selected ? scheme.secondaryContainer.withValues(alpha: 0.4) : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.busNumber(option.bus.number), style: text.titleMedium),
              Text(option.route.name),
              const SizedBox(height: 8),
              Text(l10n.missedBusGetOnAt(option.pickup.name), style: text.titleLarge),
              Text(l10n.missedBusWalk(formatWalk(l10n, option.walkMetres), walkMinutes)),
              Text(
                option.busEta == Duration.zero
                    ? l10n.missedBusBusThereNow
                    : l10n.missedBusBusIn(minutes.clamp(1, 999), formatClock(context, at)),
                style: text.titleMedium?.copyWith(color: scheme.primary),
              ),
              if (!option.reachable && !held && !boarded)
                Text(l10n.missedBusTooFar, style: TextStyle(color: Colors.orange.shade900)),
              if (!held && !boarded && seats != null)
                Text(seats > 0 ? l10n.missedBusSeats(seats) : l10n.missedBusFull),
              const SizedBox(height: 12),
              if (boarded)
                Text(l10n.holdBoarded, style: text.titleMedium?.copyWith(color: Colors.green.shade800))
              else if (held) ...[
                Row(
                  children: [
                    Icon(Icons.event_seat, color: Colors.green.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.holdHeld(option.pickup.name),
                          style: text.titleMedium?.copyWith(color: Colors.green.shade800)),
                    ),
                  ],
                ),
                TextButton(onPressed: _busy ? null : _cancel, child: Text(l10n.holdCancelButton)),
              ] else
                FilledButton.icon(
                  onPressed: _busy || seats == 0 ? null : _hold,
                  icon: const Icon(Icons.event_seat),
                  label: Text(l10n.holdSeatButton),
                ),
              if (_message case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message, style: TextStyle(color: scheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}
