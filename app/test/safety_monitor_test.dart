import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/trip/domain/fix.dart';
import 'package:where_is_my_bus/features/trip/domain/safety_monitor.dart';

void main() {
  final start = DateTime(2026, 10, 12, 7);
  var away = 0.0;
  late SafetyMonitor monitor;

  setUp(() {
    away = 0;
    monitor = SafetyMonitor(limitKmh: 60, offRouteMetres: (_, _) => away);
  });

  /// A fix every 3 seconds, like the driver's phone.
  List<SafetyEvent> drive({required int seconds, required double kmh, int from = 0}) => [
        for (var s = from; s <= from + seconds; s += 3)
          ...monitor.onFix(Fix(lat: 10.99, lng: 76.96, time: start.add(Duration(seconds: s)), speedMps: kmh / 3.6)),
      ];

  group('overspeed', () {
    test('a moment over the limit is not reported; ten seconds over is, once', () {
      expect(drive(seconds: 6, kmh: 75), isEmpty);
      expect(drive(seconds: 30, kmh: 50, from: 9), isEmpty);
      final events = drive(seconds: 60, kmh: 72, from: 42);
      expect(events, hasLength(1));
      expect(events.single.type, SafetyEventType.overspeed);
      expect(events.single.speedKmh, 72);
      expect(events.single.limitKmh, 60);
    });

    test('hovering just under the limit does not start a new episode', () {
      expect(drive(seconds: 15, kmh: 70), hasLength(1));
      expect(drive(seconds: 90, kmh: 58, from: 18), isEmpty); // not 5 under
      expect(drive(seconds: 15, kmh: 70, from: 111), isEmpty);
    });

    test('after a minute well under the limit, a new episode is reported', () {
      expect(drive(seconds: 15, kmh: 70), hasLength(1));
      expect(drive(seconds: 63, kmh: 45, from: 18), isEmpty);
      expect(drive(seconds: 15, kmh: 70, from: 84), hasLength(1));
    });
  });

  group('off route', () {
    test('a minute more than 300 m from the road is reported once, with the distance', () {
      away = 420;
      final events = drive(seconds: 120, kmh: 30);
      expect(events, hasLength(1));
      expect(events.single.type, SafetyEventType.offRoute);
      expect(events.single.distanceM, 420);
    });

    test('a short detour is not', () {
      away = 420;
      expect(drive(seconds: 45, kmh: 30), isEmpty);
      away = 20;
      expect(drive(seconds: 60, kmh: 30, from: 48), isEmpty);
    });

    test('back on the road for a minute, then off again: reported again', () {
      away = 500;
      expect(drive(seconds: 63, kmh: 30), hasLength(1));
      away = 50;
      expect(drive(seconds: 63, kmh: 30, from: 66), isEmpty);
      away = 500;
      expect(drive(seconds: 63, kmh: 30, from: 132), hasLength(1));
    });
  });
}
