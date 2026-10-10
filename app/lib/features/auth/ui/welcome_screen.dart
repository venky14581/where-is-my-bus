import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../routing/routes.dart';
import 'splash_screen.dart';
import 'widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerRight, child: LanguageToggle()),
                  const SizedBox(height: 32),
                  const Center(child: BusBadge()),
                  const SizedBox(height: 20),
                  Text(l10n.appTitle, textAlign: TextAlign.center, style: text.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeTagline,
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),
                  _RoleCard(
                    icon: Icons.school_outlined,
                    title: l10n.welcomeStudentTitle,
                    subtitle: l10n.welcomeStudentSubtitle,
                    onTap: () => context.push(Routes.studentSignIn),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.airline_seat_recline_normal_outlined,
                    title: l10n.welcomeDriverTitle,
                    subtitle: l10n.welcomeDriverSubtitle,
                    onTap: () => context.push(Routes.driverSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
