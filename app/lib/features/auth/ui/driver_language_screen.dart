import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../l10n/generated/app_localizations_en.dart';
import '../../../l10n/generated/app_localizations_ta.dart';
import 'widgets.dart';

/// Shown once, at a driver's first login. The prompt is in both languages
/// because the driver hasn't told us which one they read yet.
class DriverLanguageScreen extends ConsumerWidget {
  const DriverLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = AppLocalizationsEn();
    final ta = AppLocalizationsTa();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.translate, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(ta.chooseLanguageTitle, textAlign: TextAlign.center, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(en.chooseLanguageTitle, textAlign: TextAlign.center, style: text.titleMedium),
                  const SizedBox(height: 32),
                  for (final entry in languageNames.entries) ...[
                    SizedBox(
                      height: 72,
                      child: FilledButton.tonal(
                        onPressed: () => changeLanguage(ref, entry.key),
                        child: Text(entry.value, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${ta.chooseLanguageBody}\n${en.chooseLanguageBody}',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
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
