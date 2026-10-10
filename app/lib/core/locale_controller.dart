import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'settings_store.dart';

const _localeKey = 'locale';

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final saved = ref.read(settingsStoreProvider).read(_localeKey);
    return Locale(AppConfig.supportedLanguageCodes.contains(saved) ? saved! : 'en');
  }

  Future<void> select(String languageCode) async {
    if (!AppConfig.supportedLanguageCodes.contains(languageCode)) return;
    state = Locale(languageCode);
    await ref.read(settingsStoreProvider).write(_localeKey, languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
