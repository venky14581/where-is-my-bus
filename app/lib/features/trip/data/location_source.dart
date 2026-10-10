import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo.dart';
import '../../routes/domain/bus_route.dart';
import '../domain/fix.dart';
import '../domain/trip_plan.dart';

enum LocationAccess { granted, serviceDisabled, denied, deniedForever }

abstract interface class LocationSource {
  /// Checks that location is on and permitted, asking the driver if needed.
  Future<LocationAccess> ensureAccess();

  /// Readings roughly every 3 seconds until cancelled.
  Stream<Fix> fixes({required BusRoute route, required TripDirection direction});

  /// Opens the system screen that fixes [problem].
  Future<void> openSettings(LocationAccess problem);
}

/// The phone's GPS.
class DeviceLocationSource implements LocationSource {
  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<Fix> fixes({required BusRoute route, required TripDirection direction}) =>
      Geolocator.getPositionStream(locationSettings: _settings()).map(
        (p) => Fix(
          lat: p.latitude,
          lng: p.longitude,
          time: p.timestamp,
          speedMps: p.speed < 0 ? 0 : p.speed,
          accuracyM: p.accuracy,
          heading: p.heading < 0 ? 0 : p.heading,
          isMocked: p.isMocked,
        ),
      );

  LocationSettings _settings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 3),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.high),
    };
  }

  @override
  Future<void> openSettings(LocationAccess problem) async {
    if (problem == LocationAccess.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

/// Drives the bus along the route's road path, for demos and for testing
/// without a phone. Debug builds only; see `trip_providers.dart`.
class SimulatedDrive implements LocationSource {
  SimulatedDrive({this.speedMps = 11, this.speedup = 5, this.tick = const Duration(seconds: 3)});

  /// Reported speed, about 40 km/h.
  final double speedMps;

  /// How many simulated seconds pass per real second, so a 25 km route takes
  /// minutes instead of most of an hour.
  final int speedup;

  final Duration tick;

  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;

  @override
  Future<void> openSettings(LocationAccess problem) async {}

  @override
  Stream<Fix> fixes({required BusRoute route, required TripDirection direction}) async* {
    var path = route.path == null
        ? [for (final s in route.stops) LatLng(s.lat, s.lng)]
        : decodePolyline(route.path!);
    if (direction == TripDirection.fromCampus) path = path.reversed.toList();
    if (path.isEmpty) return;

    // Simulated time moves [speedup] times faster, so the speed implied by
    // consecutive fixes stays realistic and passes the jump check.
    var simTime = DateTime.now();
    final step = speedMps * tick.inMilliseconds / 1000 * speedup;
    final walker = _PathWalker(path);
    while (true) {
      final point = walker.current;
      yield Fix(lat: point.latitude, lng: point.longitude, time: simTime, speedMps: speedMps, accuracyM: 5);
      if (walker.done) return;
      await Future<void>.delayed(tick);
      walker.advance(step);
      simTime = simTime.add(tick * speedup);
    }
  }
}

class _PathWalker {
  _PathWalker(this.path);

  final List<LatLng> path;
  int _segment = 0;
  double _along = 0; // metres into the current segment

  bool get done => _segment >= path.length - 1;

  LatLng get current {
    if (done) return path.last;
    final a = path[_segment];
    final b = path[_segment + 1];
    final length = metresBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    final t = length == 0 ? 0.0 : _along / length;
    return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
  }

  void advance(double metres) {
    var left = metres;
    while (!done) {
      final a = path[_segment];
      final b = path[_segment + 1];
      final remaining = metresBetween(a.latitude, a.longitude, b.latitude, b.longitude) - _along;
      if (left < remaining) {
        _along += left;
        return;
      }
      left -= remaining;
      _segment++;
      _along = 0;
    }
  }
}
