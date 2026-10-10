import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../application/auth_providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final l10n = context.l10n;
    final failed = session.hasError && !session.hasValue;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BusBadge(),
              const SizedBox(height: 20),
              Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              if (failed) ...[
                Text(l10n.startupError, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(sessionProvider),
                  child: Text(l10n.retry),
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class BusBadge extends StatelessWidget {
  const BusBadge({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
      child: Icon(Icons.directions_bus_rounded, size: size * 0.55, color: scheme.onPrimaryContainer),
    );
  }
}
