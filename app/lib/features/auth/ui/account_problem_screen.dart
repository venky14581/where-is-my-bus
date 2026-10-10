import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../application/auth_providers.dart';
import '../domain/app_user.dart';
import '../domain/credentials.dart';
import '../domain/session.dart';
import 'widgets.dart';

/// Signed in, but with an account the app can't serve.
class AccountProblemScreen extends ConsumerWidget {
  const AccountProblemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final message = switch (session) {
      SignedIn(profile: AppUser(role: UserRole.office)) => l10n.accountProblemOffice,
      SignedIn(profile: null, :final email) when isDriverAccountEmail(email) =>
        l10n.accountProblemDriverNotSetUp,
      _ => l10n.accountProblemGeneric,
    };
    return AuthScaffold(
      title: l10n.accountProblemTitle,
      children: [
        Icon(Icons.no_accounts_outlined, size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(message),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l10n.signOut),
        ),
      ],
    );
  }
}
