import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/core/settings_store.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/application/trip_controller.dart';
import 'package:where_is_my_bus/features/trip/data/location_source.dart';
import 'package:where_is_my_bus/features/trip/domain/fix.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

import 'support/fakes.dart';
import 'support/trip_fakes.dart';

const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'r1', driverId: 'driver1');
const _route = BusRoute(id: 'r1', name: 'Gandhipuram – Campus', city: 'Coimbatore', stops: [
  RouteStop(id: 'a', name: 'Gandhipuram', lat: 11.000, lng: 76.96, scheduledTime: '07:00'),
  RouteStop(id: 'b', name: 'Ukkadam', lat: 10.990, lng: 76.96, scheduledTime: '07:10'),
  RouteStop(id: 'campus', name: 'Campus', lat: 10.980, lng: 76.96, scheduledTime: '07:20'),
]);

class _Harness {
  _Harness() {
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      tripRepositoryProvider.overrideWithValue(repo),
      locationSourceProvider.overrideWithValue(location),
      tripKeepAliveProvider.overrideWithValue(keepAlive),
      clockProvider.overrideWithValue(clock.call),
    ]);
  }

  final settings = InMemorySettingsStore();
  final repo = FakeTripRepository();
  final location = FakeLocationSource();
  final keepAlive = FakeKeepAlive();
  final clock = TestClock(DateTime(2026, 10, 10, 7, 0));
  late final ProviderContainer container;

  TripController get controller => container.read(tripControllerProvider.notifier);
  TripState get state => container.read(tripControllerProvider);

  Future<void> start() async {
    await controller.start(bus: _bus, route: _route, driverUid: 'driver1');
    repo.setOnline(true);
    await pump();
  }

  /// A good reading at [lat], [secondsLater] after the previous one.
  Future<void> fix(double lat, {int secondsLater = 3, bool mocked = false}) async {
    clock.advance(Duration(seconds: secondsLater));
    location.emit(Fix(lat: lat, lng: 76.96, time: clock.now, accuracyM: 5, speedMps: 10, isMocked: mocked));
    await pump();
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.container.dispose());

  test('starting creates the morning trip and keeps the app alive', () async {
    await h.start();

    expect(h.repo.started.single.tripId, '2026-10-10_bus-01_toCampus');
    expect(h.repo.started.single.direction, TripDirection.toCampus);
    expect(h.keepAlive.running, isTrue);
    expect(h.state.phase, TripPhase.running);
    expect(h.state.nextStop!.id, 'a');
    expect(h.state.totalStops, 3);
    // Not before a position exists; the rules would refuse it.
    expect(h.repo.armed, isEmpty);
  });

  test('arms the offline marker after the first position, once per connection', () async {
    await h.start();
    await h.fix(10.999);
    await h.fix(10.9986);
    expect(h.repo.armed, ['bus-01']);

    h.repo.setOnline(false);
    await h.pump();
    h.repo.setOnline(true);
    await h.pump();
    await h.fix(10.9983);
    expect(h.repo.armed, ['bus-01', 'bus-01']);
  });

  test('sends a position at most every 3 seconds', () async {
    await h.start();
    await h.fix(10.999);
    await h.fix(10.9989, secondsLater: 1); // too soon
    await h.fix(10.9986, secondsLater: 2);
    expect(h.repo.published.map((f) => f.lat), [10.999, 10.9986]);
    expect(h.state.lastSentAt, isNotNull);
  });

  test('never sends a fake GPS reading, and warns the driver', () async {
    await h.start();
    await h.fix(10.999, mocked: true);
    expect(h.repo.published, isEmpty);
    expect(h.state.mockDetected, isTrue);

    await h.fix(10.999);
    expect(h.repo.published, hasLength(1));
    expect(h.state.mockDetected, isFalse);
  });

  test('records each stop the bus reaches and remembers it on the phone', () async {
    await h.start();
    await h.fix(11.0004); // 45 m from stop a
    expect(h.repo.stopArrivals, ['a']);
    expect(h.state.reachedCount, 1);
    expect(h.state.nextStop!.id, 'b');
    expect(h.controller.savedTripFor('bus-01')!.reached, ['a']);
  });

  test('offline, keeps only the newest point and sends it when the signal returns', () async {
    await h.start();
    h.repo.setOnline(false);
    await h.pump();
    expect(h.state.online, isFalse);

    await h.fix(10.999);
    await h.fix(10.9982); // 90 m on
    expect(h.repo.published, isEmpty);

    h.repo.setOnline(true);
    await h.pump();
    expect(h.repo.published.map((f) => f.lat), [10.9982]);
    expect(h.repo.armed, ['bus-01']); // armed once the pending point is written
  });

  test('ending marks the bus ended, closes the trip and stops the service', () async {
    await h.start();
    await h.fix(10.999);
    await h.controller.end();
    await h.pump();

    expect(h.repo.liveEnded, ['bus-01']);
    expect(h.repo.ended, ['2026-10-10_bus-01_toCampus']);
    expect(h.keepAlive.running, isFalse);
    expect(h.state.phase, TripPhase.idle);
    expect(h.controller.savedTripFor('bus-01'), isNull);

    await h.fix(10.998); // the GPS stream is closed now
    expect(h.repo.published, hasLength(1));
  });

  test('restarting the app mid-trip resumes the same trip and its stops', () async {
    await h.start();
    await h.fix(11.0004);
    h.container.dispose();

    final again = _Harness();
    again.settings.values.addAll(h.settings.values);
    again.clock.now = h.clock.now;
    addTearDown(again.container.dispose);

    expect(again.controller.savedTripFor('bus-01'), isNotNull);
    await again.start();
    expect(again.repo.started.single.tripId, '2026-10-10_bus-01_toCampus');
    expect(again.state.reachedCount, 1);
    expect(again.state.nextStop!.id, 'b');
  });

  test('without location permission the trip does not start', () async {
    h.location.access = LocationAccess.deniedForever;
    await h.controller.start(bus: _bus, route: _route, driverUid: 'driver1');
    expect(h.state.phase, TripPhase.idle);
    expect(h.state.problem, TripProblem.permissionDeniedForever);
    expect(h.repo.started, isEmpty);
    expect(h.keepAlive.running, isFalse);
  });

  test('with no connection at the start, the driver is told to try again', () async {
    h.repo.failStart = true;
    await h.controller.start(bus: _bus, route: _route, driverUid: 'driver1');
    expect(h.state.problem, TripProblem.startFailed);
    expect(h.state.phase, TripPhase.idle);
  });

  test('an afternoon start is the evening trip, and closes a trip left running', () async {
    await h.start();
    h.container.dispose();

    final evening = _Harness();
    evening.settings.values.addAll(h.settings.values);
    evening.clock.now = DateTime(2026, 10, 10, 16, 30);
    addTearDown(evening.container.dispose);
    await evening.start();

    expect(evening.repo.ended, ['2026-10-10_bus-01_toCampus']);
    expect(evening.repo.started.single.tripId, '2026-10-10_bus-01_fromCampus');
    expect(evening.state.nextStop!.id, 'campus');
  });
}
