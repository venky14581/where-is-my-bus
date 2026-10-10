import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Small key-value settings kept on the device.
abstract interface class SettingsStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class HiveSettingsStore implements SettingsStore {
  HiveSettingsStore(this._box);

  static const boxName = 'settings';

  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);
}

/// Overridden in `main()` once the Hive box is open.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider must be overridden'),
);
