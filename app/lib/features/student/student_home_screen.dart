import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../auth/application/auth_providers.dart';
import '../auth/domain/session.dart';
import '../auth/ui/widgets.dart';

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
            // Module 2 replaces this card with the city, route and stop picker.
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.alt_route, size: 32),
                    const SizedBox(height: 12),
                    Text(l10n.routeNotChosenTitle, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(l10n.routeNotChosenBody),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
