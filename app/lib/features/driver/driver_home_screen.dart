import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
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
              const Spacer(),
              // The one control a driver needs. Module 3 enables it once the
              // office has assigned a bus.
              SizedBox(
                height: 120,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 40),
                  label: Text(l10n.startTrip, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.busNotAssigned, textAlign: TextAlign.center, style: text.bodyLarge),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
