import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';
import '../routes/application/route_providers.dart';
import '../routes/domain/bus_route.dart';
import '../routes/ui/scheduled_time.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    final bus = profile == null ? null : ref.watch(driverBusProvider(profile.uid)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle), actions: const [AccountMenu()]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.helloName(profile?.name ?? ''), style: text.headlineSmall),
              if (profile?.driverId case final id?) ...[
                const SizedBox(height: 4),
                Text(l10n.driverIdValue(id), style: text.titleMedium),
              ],
              if (bus != null) ...[const SizedBox(height: 20), _BusCard(bus: bus)],
              const Spacer(),
              // The one control a driver needs. Module 3 switches it on.
              SizedBox(
                height: 120,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 40),
                  label: Text(l10n.startTrip, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                bus == null ? l10n.busNotAssigned : l10n.tripTrackingNotReady,
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusCard extends ConsumerWidget {
  const _BusCard({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final routeId = bus.routeId;
    final route = routeId == null ? null : ref.watch(routeProvider(routeId)).value;
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
