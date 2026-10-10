import 'package:flutter/foundation.dart';

/// A student's notification choices, stored at `users/{uid}.alerts`.
/// The server reads the same fields; see `functions/src/audience.ts`.
@immutable
class AlertPrefs {
  const AlertPrefs({
    this.approaching = true,
    this.tripStarted = true,
    this.delays = true,
    this.announcements = true,
    this.leadStops = 2,
    this.quietDays = const {},
  });

  final bool approaching;
  final bool tripStarted;

  /// Delays, running late and breakdowns.
  final bool delays;
  final bool announcements;

  /// 1 to 3 stops before the student's own.
  final int leadStops;

  /// ISO weekdays: 1 = Monday ... 7 = Sunday.
  final Set<int> quietDays;

  static AlertPrefs fromMap(Object? raw) {
    if (raw is! Map) return const AlertPrefs();
    bool flag(String key) => raw[key] is bool ? raw[key] as bool : true;
    final lead = raw['leadStops'];
    return AlertPrefs(
      approaching: flag('approaching'),
      tripStarted: flag('tripStarted'),
      delays: flag('delays'),
      announcements: flag('announcements'),
      leadStops: lead is int && lead >= 1 && lead <= 3 ? lead : 2,
      quietDays: {
        for (final d in raw['quietDays'] as List? ?? const [])
          if (d is int && d >= 1 && d <= 7) d,
      },
    );
  }

  Map<String, Object> toMap() => {
        'approaching': approaching,
        'tripStarted': tripStarted,
        'delays': delays,
        'announcements': announcements,
        'leadStops': leadStops,
        'quietDays': quietDays.toList()..sort(),
      };

  AlertPrefs copyWith({
    bool? approaching,
    bool? tripStarted,
    bool? delays,
    bool? announcements,
    int? leadStops,
    Set<int>? quietDays,
  }) =>
      AlertPrefs(
        approaching: approaching ?? this.approaching,
        tripStarted: tripStarted ?? this.tripStarted,
        delays: delays ?? this.delays,
        announcements: announcements ?? this.announcements,
        leadStops: leadStops ?? this.leadStops,
        quietDays: quietDays ?? this.quietDays,
      );
}
