import '../../trip/domain/trip_plan.dart';

enum TransitMode { bus, train }

/// A `timetable/{id}` entry: a public bus or train the transport office
/// suggests for a college route, at a fixed time. Not tracked live.
class PublicDeparture {
  const PublicDeparture({
    required this.id,
    required this.routeId,
    required this.mode,
    required this.name,
    required this.from,
    required this.to,
    required this.departs,
    required this.direction,
    this.note,
    this.fare,
  });

  final String id;
  final String routeId;
  final TransitMode mode;

  /// What to look for, e.g. "Town bus 96A" or "Palakkad passenger".
  final String name;
  final String from;
  final String to;

  /// HH:MM, campus clock.
  final String departs;
  final TripDirection direction;
  final String? note;
  final num? fare;

  /// Minutes after midnight, or null when malformed.
  int? get minutes {
    final parts = departs.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  static PublicDeparture? tryFromMap(String id, Map<String, dynamic> d) {
    final mode = TransitMode.values.where((m) => m.name == d['mode']).firstOrNull;
    final direction = TripDirection.values.where((x) => x.name == d['direction']).firstOrNull;
    final routeId = d['routeId'];
    final name = d['name'];
    final departs = d['departs'];
    if (mode == null || direction == null || routeId is! String || name is! String || departs is! String) return null;
    return PublicDeparture(
      id: id,
      routeId: routeId,
      mode: mode,
      name: name,
      from: d['from'] as String? ?? '',
      to: d['to'] as String? ?? '',
      departs: departs,
      direction: direction,
      note: d['note'] as String?,
      fare: d['fare'] as num?,
    );
  }
}

/// The next few departures in [direction] from [now] (campus clock), soonest
/// first. Ones that left more than a couple of minutes ago are dropped.
List<PublicDeparture> nextDepartures(
  List<PublicDeparture> all, {
  required TripDirection direction,
  required DateTime now,
  int limit = 4,
}) {
  final nowMinutes = now.hour * 60 + now.minute;
  final upcoming = [
    for (final d in all)
      if (d.direction == direction && d.minutes != null && d.minutes! >= nowMinutes - 2) d,
  ]..sort((a, b) => a.minutes!.compareTo(b.minutes!));
  return upcoming.take(limit).toList();
}
