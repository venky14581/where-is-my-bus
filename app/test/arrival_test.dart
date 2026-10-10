import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:where_is_my_bus/features/eta/domain/arrival.dart';
import 'package:where_is_my_bus/features/eta/domain/route_line.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

// A straight road running south along longitude 76.96. 0.01° of latitude is
// about 1.1 km.
const _route = BusRoute(id: 'line', name: 'Line', city: 'C', stops: [
  RouteStop(id: 'a', name: 'A', lat: 11.00, lng: 76.96, scheduledTime: '07:00'),
  RouteStop(id: 'b', name: 'B', lat: 10.99, lng: 76.96, scheduledTime: '07:10'),
  RouteStop(id: 'c', name: 'C', lat: 10.97, lng: 76.96, scheduledTime: '07:15'),
  RouteStop(id: 'campus', name: 'Campus', lat: 10.96, lng: 76.96, scheduledTime: '07:30'),
]);

void main() {
  late RouteTimeline timeline;
  setUp(() => timeline = RouteTimeline.of(_route));

  group('RouteLine', () {
    test('measures distance along the path and distance off it', () {
      final line = RouteLine(const [LatLng(11.00, 76.96), LatLng(10.99, 76.96), LatLng(10.99, 76.97)]);
      expect(line.length, closeTo(1105 + 1092, 10));

      final p = line.project(10.995, 76.961); // halfway down, 109 m east
      expect(p.along, closeTo(553, 5));
      expect(p.offRoute, closeTo(109, 3));

      final corner = line.project(10.99, 76.965); // on the second leg
      expect(corner.along, closeTo(1105 + 546, 10));
      expect(corner.offRoute, lessThan(1));
    });
  });

  group('travel time follows the timetable between stops', () {
    test('halfway between A and B is 5 of the 10 scheduled minutes from B', () {
      final arrival = timeline.arrivalAt(
        stopId: 'b',
        busLat: 10.995,
        busLng: 76.96,
        direction: TripDirection.toCampus,
      );
      expect(arrival, isA<Approaching>());
      expect((arrival as Approaching).eta.inSeconds, closeTo(300, 3));
      expect(arrival.metres, closeTo(553, 5));
    });

    test('a stretch scheduled faster gives a shorter time per kilometre', () {
      // B to C is 2.2 km in 5 minutes; C to campus 1.1 km in 15.
      final toC = timeline.arrivalAt(stopId: 'c', busLat: 10.98, busLng: 76.96, direction: TripDirection.toCampus);
      expect((toC as Approaching).eta.inSeconds, closeTo(150, 3));
    });
  });

  group('arrival states', () {
    test('arriving now within 150 m of the stop, either side', () {
      for (final lat in [10.9910, 10.9890]) {
        expect(
          timeline.arrivalAt(stopId: 'b', busLat: lat, busLng: 76.96, direction: TripDirection.toCampus),
          isA<ArrivingNow>(),
        );
      }
    });

    test('passed once beyond the stop, with the recorded time when there is one', () {
      final at = DateTime(2026, 10, 10, 7, 11);
      final passed = timeline.arrivalAt(
        stopId: 'b',
        busLat: 10.975,
        busLng: 76.96,
        direction: TripDirection.toCampus,
        recordedAt: at,
      );
      expect(passed, isA<Passed>());
      expect((passed as Passed).at, at);

      final unrecorded = timeline.arrivalAt(stopId: 'b', busLat: 10.975, busLng: 76.96, direction: TripDirection.toCampus);
      expect((unrecorded as Passed).at, isNull);
    });

    test('evening trips run the route backwards', () {
      // Heading north from campus; B is still ahead, A is ahead of B.
      final toB = timeline.arrivalAt(stopId: 'b', busLat: 10.975, busLng: 76.96, direction: TripDirection.fromCampus);
      expect(toB, isA<Approaching>());
      final c = timeline.arrivalAt(stopId: 'c', busLat: 10.985, busLng: 76.96, direction: TripDirection.fromCampus);
      expect(c, isA<Passed>());
    });

    test('no estimate for a bus far from its road', () {
      expect(
        timeline.arrivalAt(stopId: 'b', busLat: 10.995, busLng: 76.98, direction: TripDirection.toCampus),
        isA<OffRoute>(),
      );
    });
  });

  test('without a usable timetable, falls back to 25 km/h', () {
    const noTimes = BusRoute(id: 'nt', name: 'N', city: 'C', stops: [
      RouteStop(id: 'a', name: 'A', lat: 11.00, lng: 76.96, scheduledTime: ''),
      RouteStop(id: 'b', name: 'B', lat: 10.99, lng: 76.96, scheduledTime: ''),
    ]);
    final arrival = RouteTimeline.of(noTimes)
        .arrivalAt(stopId: 'b', busLat: 11.00, busLng: 76.96, direction: TripDirection.toCampus);
    // 1.1 km at 25 km/h is about 2 min 39 s.
    expect((arrival as Approaching).eta.inSeconds, closeTo(159, 3));
  });

  test('the trip direction is read from the trip ID', () {
    expect(directionOfTrip('2026-10-10_bus-01_fromCampus'), TripDirection.fromCampus);
    expect(directionOfTrip('2026-10-10_bus-01_toCampus'), TripDirection.toCampus);
    expect(directionOfTrip('2026-10-10_bus-01_toCampus_simulated'), TripDirection.toCampus);
    expect(directionOfTrip(null), TripDirection.toCampus);
  });
}
