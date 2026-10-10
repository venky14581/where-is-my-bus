import '../../trip/domain/trip_plan.dart';

/// How long each stretch between two stops usually takes, learned from past
/// trips by ml/train.py (`segmentTimes/{routeId}`). The server has the same
/// rules in functions/src/learned.ts; both test the same example.
class LearnedTimes {
  const LearnedTimes({
    this.slotMinutes = 30,
    this.toCampus = const {},
    this.fromCampus = const {},
    this.delayByWeekday = const {},
  });

  final int slotMinutes;

  /// Seconds per stretch in route order, by ISO weekday and slot ("07:30").
  final Map<int, Map<String, List<int>>> toCampus;
  final Map<int, Map<String, List<int>>> fromCampus;

  /// Usual minutes late at campus in the morning, by ISO weekday.
  final Map<int, DelayPattern> delayByWeekday;

  static LearnedTimes fromMap(Map<String, dynamic> data) {
    final delays = <int, DelayPattern>{};
    final raw = data['delayByWeekday'];
    if (raw is Map) {
      for (final MapEntry(:key, :value) in raw.entries) {
        final day = int.tryParse('$key');
        if (day == null || value is! Map || value['minutes'] is! num) continue;
        delays[day] = DelayPattern(minutes: (value['minutes'] as num).round(), trips: (value['trips'] as num?)?.toInt() ?? 0);
      }
    }
    return LearnedTimes(
      slotMinutes: (data['slotMinutes'] as num?)?.toInt() ?? 30,
      toCampus: _table(data['toCampus']),
      fromCampus: _table(data['fromCampus']),
      delayByWeekday: delays,
    );
  }

  static Map<int, Map<String, List<int>>> _table(Object? raw) {
    final table = <int, Map<String, List<int>>>{};
    if (raw is! Map) return table;
    for (final MapEntry(:key, :value) in raw.entries) {
      final day = int.tryParse('$key');
      if (day == null || value is! Map) continue;
      table[day] = {
        for (final MapEntry(key: slot, value: seconds) in value.entries)
          if (seconds is List) '$slot': [for (final s in seconds) (s as num).round()],
      };
    }
    return table;
  }
}

class DelayPattern {
  const DelayPattern({required this.minutes, required this.trips});

  final int minutes;
  final int trips;
}

/// How today's buses compare with what was expected (`conditions/{date}`).
class Conditions {
  const Conditions({this.ratioSum = 0, this.count = 0});

  final double ratioSum;
  final int count;
}

/// A slot this far from the time asked for is too far to trust.
const _maxSlotDistanceMinutes = 60;

/// Today's slowness counts once this many stretches are measured...
const minStretchesForFactor = 3;

/// ...and stretches estimates by at most this much.
const maxTrafficFactor = 1.5;

/// Minutes spare between reaching the stop and the bus arriving.
const leaveBufferMinutes = 2;

/// ISO weekday and minute of the day on the campus clock (India, no
/// daylight saving), whatever zone the phone is set to.
({int weekday, int minute}) campusClock(DateTime at) {
  final local = at.toUtc().add(const Duration(hours: 5, minutes: 30));
  return (weekday: local.weekday, minute: local.hour * 60 + local.minute);
}

String slotKey(int minuteOfDay, [int slotMinutes = 30]) {
  final start = minuteOfDay ~/ slotMinutes * slotMinutes;
  return '${(start ~/ 60).toString().padLeft(2, '0')}:${(start % 60).toString().padLeft(2, '0')}';
}

int _minutesOf(String hhmm) {
  final [h, m] = hhmm.split(':').map(int.parse).toList();
  return h * 60 + m;
}

/// Seconds per stretch for a trip running [direction] at [at], from the
/// nearest slot on the same weekday. Null when nothing learned is close
/// enough or it does not fit a route of [stopCount] stops.
List<int>? learnedSegments(LearnedTimes? learned, TripDirection direction, DateTime at, int stopCount) {
  if (learned == null) return null;
  final clock = campusClock(at);
  final byDay = (direction == TripDirection.toCampus ? learned.toCampus : learned.fromCampus)[clock.weekday];
  if (byDay == null || byDay.isEmpty) return null;
  final target = clock.minute ~/ learned.slotMinutes * learned.slotMinutes;
  String? best;
  var bestDistance = 0;
  for (final key in byDay.keys) {
    final distance = (_minutesOf(key) - target).abs();
    if (best == null || distance < bestDistance || (distance == bestDistance && key.compareTo(best) < 0)) {
      best = key;
      bestDistance = distance;
    }
  }
  if (best == null || bestDistance > _maxSlotDistanceMinutes) return null;
  final segments = byDay[best]!;
  return segments.length == stopCount - 1 && segments.every((s) => s > 0) ? segments : null;
}

/// How much slower than expected today's buses are running: 1 to
/// [maxTrafficFactor]. Only adds time; a quick morning changes nothing.
double trafficFactor(Conditions? conditions) {
  final count = conditions?.count ?? 0;
  if (count < minStretchesForFactor) return 1;
  return (conditions!.ratioSum / count).clamp(1.0, maxTrafficFactor);
}

/// When to leave home to be at the stop [leaveBufferMinutes] before the bus.
DateTime leaveAt(DateTime busAtStop, int walkMinutes) =>
    busAtStop.subtract(Duration(minutes: walkMinutes + leaveBufferMinutes));

/// What an arrival estimate uses beyond the timetable.
class TravelModel {
  const TravelModel({this.segments, this.factor = 1});

  /// Learned seconds per stretch in route order, or null for the timetable.
  final List<int>? segments;

  /// Today's slowness, from [trafficFactor].
  final double factor;

  static TravelModel of({
    required LearnedTimes? learned,
    required Conditions? conditions,
    required TripDirection direction,
    required DateTime at,
    required int stopCount,
  }) =>
      TravelModel(
        segments: learnedSegments(learned, direction, at, stopCount),
        factor: trafficFactor(conditions),
      );
}
