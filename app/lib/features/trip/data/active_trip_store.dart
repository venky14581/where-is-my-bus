import 'dart:convert';

import '../../../core/settings_store.dart';
import '../domain/trip_plan.dart';

/// The trip in progress, saved on the phone so it carries on after the app
/// is closed and reopened mid-trip.
class ActiveTrip {
  const ActiveTrip({
    required this.tripId,
    required this.busId,
    required this.routeId,
    required this.direction,
    this.reached = const [],
  });

  final String tripId;
  final String busId;
  final String routeId;
  final TripDirection direction;

  /// Stop IDs already recorded, so a restart does not record them again.
  final List<String> reached;

  ActiveTrip withReached(Iterable<String> ids) =>
      ActiveTrip(tripId: tripId, busId: busId, routeId: routeId, direction: direction, reached: [...ids]);

  Map<String, Object> toJson() => {
        'tripId': tripId,
        'busId': busId,
        'routeId': routeId,
        'direction': direction.name,
        'reached': reached,
      };

  static ActiveTrip? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final direction = TripDirection.values.where((d) => d.name == json['direction']).firstOrNull;
    if (direction == null || json['tripId'] is! String || json['busId'] is! String) return null;
    return ActiveTrip(
      tripId: json['tripId'] as String,
      busId: json['busId'] as String,
      routeId: json['routeId'] as String? ?? '',
      direction: direction,
      reached: [for (final id in json['reached'] as List? ?? const []) '$id'],
    );
  }
}

class ActiveTripStore {
  ActiveTripStore(this._settings);

  static const _key = 'activeTrip';

  final SettingsStore _settings;

  ActiveTrip? read() {
    final raw = _settings.read(_key);
    if (raw == null) return null;
    try {
      return ActiveTrip.tryFromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(ActiveTrip trip) => _settings.write(_key, jsonEncode(trip.toJson()));

  Future<void> clear() => _settings.remove(_key);
}
