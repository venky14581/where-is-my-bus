import 'dart:async';

import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/data/location_source.dart';
import 'package:where_is_my_bus/features/trip/data/trip_keep_alive.dart';
import 'package:where_is_my_bus/features/trip/data/trip_repository.dart';
import 'package:where_is_my_bus/features/trip/domain/fix.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

/// GPS readings the test pushes by hand.
class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.access = LocationAccess.granted});

  LocationAccess access;
  final _fixes = StreamController<Fix>.broadcast();
  final settingsOpened = <LocationAccess>[];

  void emit(Fix fix) => _fixes.add(fix);

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<Fix> fixes({required BusRoute route, required TripDirection direction}) => _fixes.stream;

  @override
  Future<void> openSettings(LocationAccess problem) async => settingsOpened.add(problem);
}

class FakeTripRepository implements TripRepository {
  final started = <TripStart>[];
  final ended = <String>[];
  final published = <Fix>[];
  final liveEnded = <String>[];
  final armed = <String>[];
  final stopArrivals = <String>[];
  bool failStart = false;
  final _connection = StreamController<bool>.broadcast();

  void setOnline(bool online) => _connection.add(online);

  @override
  Future<void> startTrip(TripStart start) async {
    if (failStart) throw Exception('offline');
    started.add(start);
  }

  @override
  Future<void> endTrip(String tripId) async => ended.add(tripId);

  @override
  Future<void> publishPosition({required String busId, required String tripId, required Fix fix}) async =>
      published.add(fix);

  @override
  Future<void> armDisconnect(String busId) async => armed.add(busId);

  @override
  Future<void> markLiveEnded({required String busId, required String tripId}) async => liveEnded.add(busId);

  @override
  Future<void> recordStopArrival({required String tripId, required String stopId, required DateTime at}) async =>
      stopArrivals.add(stopId);

  @override
  Stream<bool> connection() => _connection.stream;
}

class FakeKeepAlive implements TripKeepAlive {
  bool running = false;

  @override
  Future<void> start({required String title, required String text}) async => running = true;

  @override
  Future<void> stop() async => running = false;
}

/// A clock the test moves forward.
class TestClock {
  TestClock(this.now);

  DateTime now;

  void advance(Duration by) => now = now.add(by);

  DateTime call() => now;
}
