import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/missed_bus/domain/missed_bus.dart';
import 'package:where_is_my_bus/features/missed_bus/domain/public_transport.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

import 'support/fakes.dart';

const _email = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _uid = 'uid-$_email';
final _now = DateTime(2026, 10, 10, 7);

const _rsPuram = BusRoute(id: 'cbe-rs-puram', name: 'R.S. Puram – Campus', city: 'Coimbatore', stops: [
  RouteStop(id: 'rs-puram', name: 'R.S. Puram', lat: 11.009, lng: 76.95, scheduledTime: '07:05'),
  RouteStop(id: 'selvapuram', name: 'Selvapuram', lat: 10.99, lng: 76.94, scheduledTime: '07:15'),
  RouteStop(id: 'kovaipudur-pirivu', name: 'Kovaipudur Pirivu', lat: 10.944, lng: 76.933, scheduledTime: '07:30'),
  testCampus,
]);
const _ownBus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram');
const _otherBus = Bus(id: 'bus-02', number: 'TN 37 AB 1202', capacity: 50, routeId: 'cbe-rs-puram');
const _pkdBus = Bus(id: 'bus-03', number: 'TN 37 AB 1203', capacity: 45, routeId: 'pkd-town');
const _tripId = '2026-10-10_bus-02_toCampus';
const _trip = RunningTrip(
  id: _tripId,
  busId: 'bus-02',
  routeId: 'cbe-rs-puram',
  direction: TripDirection.toCampus,
  passHolders: 44,
  altHeld: 1,
);
const _pkdTrip = RunningTrip(id: '2026-10-10_bus-03_toCampus', busId: 'bus-03', routeId: 'pkd-town', direction: TripDirection.toCampus);

/// The R.S. Puram bus waiting at its first stop.
LiveBus _liveAt(RouteStop stop, {String busId = 'bus-02', String tripId = _tripId, String status = 'running', DateTime? at}) =>
    LiveBus(busId: busId, lat: stop.lat, lng: stop.lng, updatedAt: at ?? _now, status: status, tripId: tripId);

/// Close to Selvapuram: about 200 m on foot.
const _nearSelvapuram = LatLng(10.991, 76.941);

List<RideOption> _options({
  List<RunningTrip> trips = const [_trip],
  Map<String, LiveBus>? live,
  Map<String, Map<String, DateTime>> stopTimes = const {},
  LatLng from = _nearSelvapuram,
  Map<String, String> heldStops = const {},
}) =>
    MissedBus.options(
      studentRouteId: 'cbe-gandhipuram',
      trips: trips,
      acceptsFrom: const {'cbe-rs-puram': ['cbe-gandhipuram'], 'cbe-gandhipuram': ['cbe-rs-puram'], 'pkd-town': []},
      routes: {_rsPuram.id: _rsPuram, for (final r in testRoutes) r.id: r},
      buses: {_otherBus.id: _otherBus, _pkdBus.id: _pkdBus, _ownBus.id: _ownBus},
      live: live ?? {'bus-02': _liveAt(_rsPuram.stops.first)},
      stopTimes: stopTimes,
      fromLat: from.latitude,
      fromLng: from.longitude,
      serverNow: _now,
      heldStops: heldStops,
    );

PublicDeparture _public(String id, String departs, {TransitMode mode = TransitMode.bus, TripDirection direction = TripDirection.toCampus}) =>
    PublicDeparture(
      id: id,
      routeId: 'cbe-gandhipuram',
      mode: mode,
      name: mode == TransitMode.train ? 'Passenger train' : 'Town bus 96',
      from: 'Gandhipuram',
      to: 'Ettimadai',
      departs: departs,
      direction: direction,
    );

void main() {
  test('public departures: the next ones in the direction of travel, soonest first', () {
    final all = [
      _public('late', '08:10'),
      _public('gone', '06:50'),
      _public('just', '06:59'),
      _public('train', '07:25', mode: TransitMode.train),
      _public('evening', '17:30', direction: TripDirection.fromCampus),
    ];
    final next = nextDepartures(all, direction: TripDirection.toCampus, now: DateTime(2026, 10, 10, 7));
    expect(next.map((d) => d.id), ['just', 'train', 'late']);
  });

  group('ride options', () {
    test('only buses the office allows, with the nearest stop reachable in time', () {
      final options = _options(trips: const [_trip, _pkdTrip], live: {
        'bus-02': _liveAt(_rsPuram.stops.first),
        'bus-03': _liveAt(testRoutes[1].stops.first, busId: 'bus-03', tripId: _pkdTrip.id),
      });
      expect(options, hasLength(1));
      final option = options.single;
      expect(option.bus.number, 'TN 37 AB 1202');
      expect(option.pickup.id, 'selvapuram');
      expect(option.busEta, const Duration(minutes: 10));
      expect(option.walkMetres, closeTo(200, 10));
      expect(option.reachable, isTrue);
      // 50 seats, 44 kept for the route's own pass holders, 1 already held.
      expect(option.freeSeats, 5);
    });

    test('a stop the bus will beat you to is offered with a warning when nothing is reachable', () {
      // 1.4 km from Selvapuram: about 24 minutes on foot against a 10-minute bus.
      final option = _options(from: const LatLng(10.98, 76.935)).single;
      expect(option.pickup.id, 'selvapuram');
      expect(option.reachable, isFalse);
    });

    test('stops the bus has passed, and buses without a fresh position, are not offered', () {
      expect(_options(stopTimes: {_tripId: {'selvapuram': _now}}), isEmpty);
      expect(_options(live: {'bus-02': _liveAt(_rsPuram.stops.first, status: 'offline')}), isEmpty);
      expect(_options(live: {'bus-02': _liveAt(_rsPuram.stops.first, tripId: 'yesterday')}), isEmpty);
    });

    test('a held seat keeps its stop', () {
      expect(_options(heldStops: {_tripId: 'kovaipudur-pirivu'}).single.pickup.id, 'kovaipudur-pirivu');
      // At the held stop now: still shown while the rider boards.
      final boarding = _options(
        heldStops: {_tripId: 'selvapuram'},
        live: {'bus-02': _liveAt(_rsPuram.stops[1])},
        stopTimes: {_tripId: {'rs-puram': _now, 'selvapuram': _now}},
      ).single;
      expect((boarding.pickup.id, boarding.busEta), ('selvapuram', Duration.zero));
    });

    test('seats are unknown until the server has counted pass holders', () {
      expect(MissedBus.freeSeats(50, const RunningTrip(id: 't', busId: 'b', routeId: 'r', direction: TripDirection.toCampus)), isNull);
      expect(MissedBus.freeSeats(50, const RunningTrip(id: 't', busId: 'b', routeId: 'r', direction: TripDirection.toCampus, passHolders: 52)), 0);
    });
  });

  group('missed-bus screen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await settle(tester);
    }

    Future<FakeMissedBusRepository> open(WidgetTester tester, {bool passValid = true}) async {
      final auth = FakeAuthRepository()
        ..addStudent(_email, 'bus-pass-123',
            routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: passValid, passValidUntil: '2026-12-31');
      final live = FakeLiveRepository()..put(_liveAt(_rsPuram.stops.first));
      final missed = FakeMissedBusRepository()
        ..trips.add(_trip)
        ..access['cbe-rs-puram'] = ['cbe-gandhipuram']
        ..holder = _uid;
      await pumpApp(
        tester,
        auth,
        routes: FakeRouteRepository(auth, routes: [...testRoutes, _rsPuram], buses: const [_ownBus, _otherBus]),
        live: live,
        missedBus: missed,
        locate: () async => _nearSelvapuram,
      );
      await tap(tester, find.text("I'm a student"));
      await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
      await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
      await tap(tester, find.text('Missed your bus?'));
      return missed;
    }

    testWidgets('shows the other bus, where to get on, and holds a seat', (tester) async {
      final missed = await open(tester);

      expect(find.text('Bus TN 37 AB 1202'), findsOneWidget);
      expect(find.text('Get on at Selvapuram'), findsOneWidget);
      expect(find.text('200 m walk, about 3 min'), findsOneWidget);
      expect(find.text('Bus there in 10 min, around 7:10 AM'), findsOneWidget);
      expect(find.text('5 seats for other routes'), findsOneWidget);
      expect(find.text('Distances from where you are now.'), findsOneWidget);

      await tap(tester, find.text('Hold a seat'));
      expect(missed.requests.single, (tripId: _tripId, stopId: 'selvapuram'));
      expect(find.text('Seat held. Be at Selvapuram and show your pass to the driver.'), findsOneWidget);

      await tap(tester, find.text('Give up seat'));
      expect(find.text('Hold a seat'), findsOneWidget);
    });

    testWidgets('a full bus says so', (tester) async {
      final missed = await open(tester);
      missed.nextResult = HoldResult.full;
      await tap(tester, find.text('Hold a seat'));
      expect(find.text('Sorry, the last seat has just gone.'), findsOneWidget);
    });

    testWidgets("the driver sees who is waiting for a held seat, in stop order", (tester) async {
      final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
      const bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001');
      final missed = FakeMissedBusRepository()
        ..holds['2026-10-10_bus-01_toCampus'] = {
          'b': const SeatHold(uid: 'b', name: 'Bala', stopId: 'ukkadam', status: HoldStatus.held),
          'a': const SeatHold(uid: 'a', name: 'Asha', stopId: 'gandhipuram', status: HoldStatus.held),
          'c': const SeatHold(uid: 'c', name: 'Chitra', stopId: 'ukkadam', status: HoldStatus.boarded),
        };
      await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: const [bus]), missedBus: missed);
      await tap(tester, find.text("I'm a driver"));
      await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
      await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
      await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
      expect(find.text('Riders from other routes'), findsNothing);
      await tap(tester, find.text('Start Trip'));

      await tester.ensureVisible(find.text('Riders from other routes'));
      final asha = tester.getTopLeft(find.text('Asha at Gandhipuram Bus Stand'));
      final bala = tester.getTopLeft(find.text('Bala at Ukkadam'));
      expect(asha.dy, lessThan(bala.dy));
      // Already on board: no need to stop for them.
      expect(find.textContaining('Chitra'), findsNothing);
    });

    testWidgets('public buses and trains are offered too, even without a pass', (tester) async {
      final auth = FakeAuthRepository()
        ..addStudent(_email, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: false);
      final missed = FakeMissedBusRepository()
        ..timetable.addAll([_public('t', '07:25', mode: TransitMode.train), _public('b', '07:40')]);
      await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: const [_ownBus]), missedBus: missed);
      await tap(tester, find.text("I'm a student"));
      await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
      await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
      await tap(tester, find.text('Missed your bus?'));

      expect(find.text('You need a valid bus pass to ride another college bus.'), findsOneWidget);
      expect(find.text('Public bus and train'), findsOneWidget);
      expect(find.text('Passenger train'), findsOneWidget);
      expect(find.text('Leaves 7:25 AM'), findsOneWidget);
      expect(find.text('Leaves 7:40 AM'), findsOneWidget);
    });

    testWidgets('without a valid pass there is nothing to hold', (tester) async {
      await open(tester, passValid: false);
      expect(find.text('You need a valid bus pass to ride another college bus.'), findsOneWidget);
      expect(find.text('Hold a seat'), findsNothing);
    });
  });
}
