import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/locale_controller.dart';
import 'core/theme.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/domain/session.dart';
import 'routing/app_router.dart';

class WhereIsMyBusApp extends ConsumerWidget {
  const WhereIsMyBusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follow the language saved on the profile when it first loads or is
    // changed on another device. Unrelated session updates leave a local
    // choice alone.
    ref.listen(sessionProvider, (previous, next) {
      final before = _profileLanguage(previous?.value);
      final after = _profileLanguage(next.value);
      if (after != null && after != before) {
        ref.read(localeControllerProvider.notifier).select(after);
      }
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: ref.watch(localeControllerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }

  static String? _profileLanguage(Session? session) =>
      session is SignedIn ? session.profile?.language : null;
}
