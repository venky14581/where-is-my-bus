import '../../core/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';
import '../routes/application/route_providers.dart';
import '../routes/domain/bus_route.dart';
import '../../routing/routes.dart';
import '../routes/ui/scheduled_time.dart';
import '../trip/application/trip_controller.dart';
import '../trip/data/location_source.dart';
import '../trip/data/trip_repository.dart';
import '../trip/domain/trip_plan.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    final bus = profile == null ? null : ref.watch(driverBusProvider(profile.uid)).value;
    final routeId = bus?.routeId;
    final route = routeId == null ? null : ref.watch(routeProvider(routeId)).value;
    final trip = ref.watch(tripControllerProvider);
    final running = trip.phase == TripPhase.running;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        // Signing out mid-trip would leave the bus frozen on every map.
        actions: [if (!running) const AccountMenu()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.helloName(profile?.name ?? ''), style: text.headlineSmall),
            if (profile?.driverId case final id?) Text(l10n.driverIdValue(id), style: text.titleMedium),
            if (bus != null) ...[const SizedBox(height: 16), _BusCard(bus: bus, route: route)],
            const SizedBox(height: 24),
            if (bus == null)
              ..._idleButton(context, l10n.busNotAssigned)
            else if (route != null && profile != null)
              _TripControls(bus: bus, route: route, driverUid: profile.uid)
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  List<Widget> _idleButton(BuildContext context, String note) => [
        const _BigButton(label: null, onPressed: null),
        const SizedBox(height: 16),
        Text(note, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      ];
}

/// The single Start Trip / End Trip control and what the driver needs to
/// know while a trip runs.
class _TripControls extends ConsumerStatefulWidget {
  const _TripControls({required this.bus, required this.route, required this.driverUid});

  final Bus bus;
  final BusRoute route;
  final String driverUid;

  @override
  ConsumerState<_TripControls> createState() => _TripControlsState();
}

class _TripControlsState extends ConsumerState<_TripControls> {
  @override
  void initState() {
    super.initState();
    // The app was closed mid-trip: carry on sending without a tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(tripControllerProvider.notifier);
      if (ref.read(tripControllerProvider).phase == TripPhase.idle &&
          controller.savedTripFor(widget.bus.id) != null) {
        _start();
      }
    });
  }

  void _start() => ref
      .read(tripControllerProvider.notifier)
      .start(bus: widget.bus, route: widget.route, driverUid: widget.driverUid);

  Future<void> _confirmEnd() async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endTripConfirmTitle),
        content: Text(l10n.endTripConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.endTrip)),
        ],
      ),
    );
    if (yes == true) await ref.read(tripControllerProvider.notifier).end();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final trip = ref.watch(tripControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final direction = trip.direction ?? directionAt(ref.read(clockProvider)());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          direction == TripDirection.toCampus ? l10n.directionToCampus : l10n.directionFromCampus,
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: 12),
        switch (trip.phase) {
          TripPhase.idle => _BigButton(label: l10n.startTrip, icon: Icons.play_arrow_rounded, onPressed: _start),
          TripPhase.starting => const _BigButton(label: null, onPressed: null, busy: true),
          TripPhase.running => _BigButton(
              label: l10n.endTrip,
              icon: Icons.stop_rounded,
              color: scheme.error,
              onColor: scheme.onError,
              onPressed: _confirmEnd,
            ),
        },
        const SizedBox(height: 16),
        if (trip.problem case final problem?) _ProblemBanner(problem: problem),
        if (trip.mockDetected) ErrorBanner(l10n.mockLocationWarning),
        if (trip.phase == TripPhase.running) ...[
          SizedBox(
            height: 64,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push(Routes.driverScan),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: Text(l10n.scanPassButton, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 16),
          _RunningStatus(trip: trip),
          const SizedBox(height: 16),
          const _IssueButtons(),
        ],
      ],
    );
  }
}

/// Running late and Breakdown: one tap tells every rider on the route.
class _IssueButtons extends ConsumerStatefulWidget {
  const _IssueButtons();

  @override
  ConsumerState<_IssueButtons> createState() => _IssueButtonsState();
}

class _IssueButtonsState extends ConsumerState<_IssueButtons> {
  /// Reports already sent this trip; each can be sent once.
  final _sent = <TripIssue>{};
  TripIssue? _sending;

  /// Shown under the buttons. Not a snackbar, which would cover them.
  String? _message;

  Future<void> _report(TripIssue issue) async {
    final l10n = context.l10n;
    if (issue == TripIssue.breakdown) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.breakdownConfirmTitle),
          content: Text(l10n.breakdownConfirmBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.reportButton)),
          ],
        ),
      );
      if (yes != true) return;
    }
    setState(() {
      _sending = issue;
      _message = null;
    });
    final ok = await ref.read(tripControllerProvider.notifier).report(issue);
    if (!mounted) return;
    setState(() {
      _sending = null;
      if (ok) _sent.add(issue);
      _message = ok ? l10n.driverReportSent : l10n.errorNetwork;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget button(TripIssue issue, IconData icon, String label, {Color? colour}) => Expanded(
          child: SizedBox(
            height: 64,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: colour),
              onPressed: _sending != null || _sent.contains(issue) ? null : () => _report(issue),
              icon: _sent.contains(issue) ? const Icon(Icons.check) : Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 18)),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            button(TripIssue.late, Icons.schedule, l10n.driverReportLate),
            const SizedBox(width: 12),
            button(TripIssue.breakdown, Icons.car_crash_outlined, l10n.driverReportBreakdown, colour: scheme.error),
          ],
        ),
        if (_message case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _RunningStatus extends StatefulWidget {
  const _RunningStatus({required this.trip});

  final TripState trip;

  @override
  State<_RunningStatus> createState() => _RunningStatusState();
}

class _RunningStatusState extends State<_RunningStatus> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Refreshes "Sent 4 s ago".
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final trip = widget.trip;
    final sent = trip.lastSentAt;
    final next = trip.nextStop;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(trip.online ? Icons.sensors : Icons.signal_cellular_connected_no_internet_0_bar,
                    color: trip.online ? Colors.green.shade700 : Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.sharingLocation, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(sent == null
                ? l10n.waitingForGps
                : l10n.lastSentSecondsAgo(DateTime.now().difference(sent).inSeconds.clamp(0, 9999))),
            if (!trip.online) ...[const SizedBox(height: 8), Text(l10n.noSignal)],
            const Divider(height: 24),
            Text(next == null ? l10n.lastStopReached : l10n.nextStopName(next.name), style: text.titleMedium),
            Text(l10n.stopsReached(trip.reachedCount, trip.totalStops)),
          ],
        ),
      ),
    );
  }
}

class _ProblemBanner extends ConsumerWidget {
  const _ProblemBanner({required this.problem});

  final TripProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (message, fix) = switch (problem) {
      TripProblem.locationOff => (l10n.problemLocationOff, LocationAccess.serviceDisabled),
      TripProblem.permissionDenied => (l10n.problemPermissionDenied, null),
      TripProblem.permissionDeniedForever => (l10n.problemPermissionDeniedForever, LocationAccess.deniedForever),
      TripProblem.startFailed => (l10n.problemStartFailed, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorBanner(message),
        if (fix != null)
          TextButton(
            onPressed: () => ref.read(locationSourceProvider).openSettings(fix),
            child: Text(l10n.openSettings),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.onColor,
    this.busy = false,
  });

  final String? label;
  final IconData? icon;
  final Color? color;
  final Color? onColor;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 120,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? Colors.green.shade700,
          foregroundColor: onColor ?? Colors.white,
        ),
        onPressed: onPressed,
        icon: busy
            ? const SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3))
            : Icon(icon ?? Icons.play_arrow_rounded, size: 40),
        label: Text(label ?? l10n.startTrip, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus, required this.route});

  final Bus bus;
  final BusRoute? route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final route = this.route;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_rounded, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text(bus.number, style: text.headlineSmall)),
              ],
            ),
            if (route != null) ...[
              const SizedBox(height: 8),
              Text(route.name, style: text.titleMedium),
              Text([
                l10n.stopCount(route.pickupStops.length),
                if (route.stops.isNotEmpty)
                  l10n.firstPickupAt(formatScheduledTime(context, route.stops.first.scheduledTime)),
              ].join(' · ')),
            ],
          ],
        ),
      ),
    );
  }
}
