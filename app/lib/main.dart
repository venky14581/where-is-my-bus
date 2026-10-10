import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';
import 'core/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final settings = await Hive.openBox<String>(HiveSettingsStore.boxName);
  await initFirebase();

  runApp(ProviderScope(
    overrides: [settingsStoreProvider.overrideWithValue(HiveSettingsStore(settings))],
    child: const WhereIsMyBusApp(),
  ));
}
