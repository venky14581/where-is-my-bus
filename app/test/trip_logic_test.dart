import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/core/geo.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/domain/fix.dart';
import 'package:where_is_my_bus/features/trip/domain/fix_filter.dart';
import 'package:where_is_my_bus/features/trip/domain/stop_detector.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

final _t0 = DateTime(2026, 10, 10, 7);

// About 111 m per 0.001° of latitude.
Fix _fix(double lat, int seconds, {double lng = 76.96, double accuracy = 5, bool mocked = false}) =>
    Fix(lat: lat, lng: lng, time: _t0.add(Duration(seconds: seconds)), accuracyM: accuracy, isMocked: mocked);

const _stops = [
  RouteStop(id: 'a', name: 'A', lat: 11.000, lng: 76.96, scheduledTime: '07:00'),
  RouteStop(id: 'b', name: 'B', lat: 10.990, lng: 76.96, scheduledTime: '07:10'),
  RouteStop(id: 'c', name: 'Campus', lat: 10.980, lng: 76.96, scheduledTime: '07:20'),
];

void main() {
  group('FixFilter', () {
    test('accepts normal driving', () {
      final filter = FixFilter();
      expect(filter.check(_fix(11.000, 0)), FixVerdict.accepted);
      expect(filter.check(_fix(10.9997, 3)), FixVerdict.accepted); // ~33 m in 3 s
    });

    test('rejects fake GPS and vague readings', () {
      final filter = FixFilter();
      expect(filter.check(_fix(11.0, 0, mocked: true)), FixVerdict.mocked);
      expect(filter.check(_fix(11.0, 0, accuracy: 500)), FixVerdict.inaccurate);
    });

    test('rejects a jump the bus could not make, then recovers if the jump was real', () {
      final filter = FixFilter();
      filter.check(_fix(11.000, 0));
      // 1.1 km in 3 seconds.
      for (var i = 1; i < FixFilter.jumpsBeforeReset; i++) {
        expect(filter.check(_fix(10.990, 3 * i)), FixVerdict.impossibleJump);
      }
      // Still there after five tries: the first fix was the wrong one.
      expect(filter.check(_fix(10.990, 15)), FixVerdict.accepted);
      expect(filter.check(_fix(10.9897, 18)), FixVerdict.accepted);
    });

    test('allows for GPS error when two readings are close', () {
      final filter = FixFilter();
      filter.check(_fix(11.0000, 0, accuracy: 60));
      expect(filter.check(_fix(10.9992, 1, accuracy: 60)), FixVerdict.accepted); // 90 m, within error
    });
  });

  group('StopDetector', () {
    test('reports each stop once, when the bus comes within 80 m', () {
      final detector = StopDetector(_stops);
      expect(detector.nextStop!.id, 'a');
      expect(detector.onFix(_fix(11.0005, 0)).map((s) => s.id), ['a']); // 55 m away
      expect(detector.onFix(_fix(11.0004, 3)), isEmpty);
      expect(detector.nextStop!.id, 'b');
      expect(detector.onFix(_fix(10.995, 60)), isEmpty);
      expect(detector.onFix(_fix(10.990, 120)).map((s) => s.id), ['b']);
    });

    test('a skipped stop is never reported, and the next stop moves past it', () {
      final detector = StopDetector(_stops, reached: ['a']);
      expect(detector.onFix(_fix(10.980, 0)).map((s) => s.id), ['c']);
      expect(detector.nextStop, isNull);
      expect(detector.reached, {'a', 'c'});
    });
  });

  group('trip plan', () {
    test('morning trips go to campus, evening trips come back', () {
      expect(directionAt(DateTime(2026, 10, 10, 6, 45)), TripDirection.toCampus);
      expect(directionAt(DateTime(2026, 10, 10, 16, 30)), TripDirection.fromCampus);
    });

    test('one trip ID per bus, day and direction', () {
      expect(
        tripIdFor(busId: 'bus-01', local: DateTime(2026, 1, 5, 7), direction: TripDirection.toCampus),
        '2026-01-05_bus-01_toCampus',
      );
    });

    test('evening trips visit the stops in reverse', () {
      const route = BusRoute(id: 'r', name: 'R', city: 'C', stops: _stops);
      expect(stopsInTravelOrder(route, TripDirection.fromCampus).map((s) => s.id), ['c', 'b', 'a']);
    });
  });

  test('decodePolyline reads the encoding OSRM and Google use', () {
    // Example from Google's polyline documentation.
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-6));
    expect(points[0].longitude, closeTo(-120.2, 1e-6));
    expect(points[2].latitude, closeTo(43.252, 1e-6));
    expect(points[2].longitude, closeTo(-126.453, 1e-6));
  });
}
