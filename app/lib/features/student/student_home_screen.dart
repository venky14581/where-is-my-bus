import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../routing/routes.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';
import '../routes/application/route_providers.dart';
import '../routes/ui/scheduled_time.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle), actions: const [AccountMenu()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.helloName(profile?.name ?? ''), style: text.headlineSmall),
            const SizedBox(height: 20),
            if (profile?.routeId case final routeId?)
              _HomeStopCard(routeId: routeId, stopId: profile?.stopId),
          ],
        ),
      ),
    );
  }
}

class _HomeStopCard extends ConsumerWidget {
  const _HomeStopCard({required this.routeId, required this.stopId});

  final String routeId;
  final String? stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final route = ref.watch(routeProvider(routeId));
    final bus = ref.watch(routeBusProvider(routeId)).value;
    void change() => context.push(Routes.studentChooseRoute);

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: route.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(l10n.startupError),
          data: (route) {
            final stop = route?.stopById(stopId);
            if (route == null || stop == null) {
              // The office removed the route or the stop since it was chosen.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.routeMissing),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: change, child: Text(l10n.chooseRouteButton)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.yourStopTitle, style: text.labelLarge)),
                    TextButton(onPressed: change, child: Text(l10n.changeButton)),
                  ],
                ),
                Text(stop.name, style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(route.name),
                if (bus != null) Text(l10n.busNumber(bus.number)),
                const SizedBox(height: 12),
                Text(
                  l10n.busDueAt(formatScheduledTime(context, stop.scheduledTime)),
                  style: text.titleMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
