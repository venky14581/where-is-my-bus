import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

export '../l10n/generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Language names are always written in their own script so a reader can
/// find theirs whatever the current language is.
const languageNames = {'en': 'English', 'ta': 'தமிழ்'};
