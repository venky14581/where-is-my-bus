import 'package:latlong2/latlong.dart';

import '../../../core/geo.dart';
import '../../routes/domain/bus_route.dart';
import '../../trip/domain/trip_plan.dart';
import 'learned_times.dart';
import 'route_line.dart';

/// What a student should be told about the bus and their stop.
sealed class Arrival {
  const Arrival();
}

/// The bus is on its way; [eta] is the expected time until it reaches the stop.
final class Approaching extends Arrival {
  const Approaching(this.eta, this.metres);

  final Duration eta;
  final double metres;
}

/// Within [RouteTimeline.atStopM] of the stop.
final class ArrivingNow extends Arrival {
  const ArrivingNow();
}

/// Already gone past. [at] is the recorded time at the stop, when known.
final class Passed extends Arrival {
  const Passed(this.at);

  final DateTime? at;
}

/// Too far from its usual road to estimate.
final class OffRoute extends Arrival {
  const OffRoute();
}

/// The direction a trip runs, from its ID ({date}_{busId}_{direction}...).
TripDirection directionOfTrip(String? tripId) =>
    tripId != null && tripId.contains(TripDirection.fromCampus.name)
        ? TripDirection.fromCampus
        : TripDirection.toCampus;

/// A route's stops placed along its road path, with the timetable (or the
/// learned times between stops) spread over the distance between them.
class RouteTimeline {
  RouteTimeline._(this.route, this.line, this._stopAlong, this._schedule);

  /// Close enough to call it "at the stop": a bus bay plus GPS error.
  static const atStopM = 150.0;

  /// Further than this from the path, any estimate would be a guess.
  static const offRouteM = 500.0;

  /// Used where the timetable cannot help: before the first stop, after the
  /// last, or if times are missing. About right for a college bus with stops.
  static const fallbackSpeedMps = 25 / 3.6;

  final BusRoute route;
  final RouteLine line;
  final Map<String, double> _stopAlong;

  /// Scheduled seconds from the first stop, by stop, in path order. Only
  /// kept when the times increase along the route.
  final List<({double along, double seconds})>? _schedule;

  static final _cache = <String, RouteTimeline>{};

  /// Built once per route and path.
  factory RouteTimeline.of(BusRoute route) {
    final key = '${route.id}|${route.path?.hashCode}|${route.stops.length}';
    return _cache[key] ??= _build(route);
  }

  static RouteTimeline _build(BusRoute route) {
    final path = route.path;
    final line = RouteLine(path != null && path.isNotEmpty
        ? decodePolyline(path)
        : [for (final s in route.stops) LatLng(s.lat, s.lng)]);
    final along = {for (final s in route.stops) s.id: line.project(s.lat, s.lng).along};

    List<({double along, int minutes})>? schedule = [];
    for (final stop in route.stops) {
      final minutes = _parseMinutes(stop.scheduledTime);
      if (minutes == null) {
        schedule = null;
        break;
      }
      schedule!.add((along: along[stop.id]!, minutes: minutes));
    }
    if (schedule != null) {
      final times = schedule;
      for (var i = 1; i < times.length; i++) {
        final ordered = times[i].along > times[i - 1].along && times[i].minutes >= times[i - 1].minutes;
        if (!ordered) {
          schedule = null;
          break;
        }
      }
    }
    if (schedule == null || schedule.length < 2) return RouteTimeline._(route, line, along, null);
    final start = schedule.first.minutes;
    return RouteTimeline._(route, line, along, [
      for (final s in schedule) (along: s.along, seconds: (s.minutes - start) * 60.0),
    ]);
  }

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  double? alongOf(String stopId) => _stopAlong[stopId];

  /// Expected travel time between two points on the path, in either order:
  /// from learned times when [travel] has them, else the timetable, then
  /// stretched by today's slowness.
  Duration travelTime(double fromAlong, double toAlong, {TravelModel? travel}) {
    final profile = _learnedProfile(travel?.segments) ?? _schedule;
    final seconds = (_secondsAt(toAlong, profile) - _secondsAt(fromAlong, profile)).abs();
    return Duration(seconds: (seconds * (travel?.factor ?? 1)).round());
  }

  /// Learned seconds per stretch placed on the path, like the timetable.
  /// Null if they do not fit the route's stops.
  List<({double along, double seconds})>? _learnedProfile(List<int>? segments) {
    if (segments == null || segments.length != route.stops.length - 1) return null;
    final profile = <({double along, double seconds})>[];
    var seconds = 0.0;
    for (final (i, stop) in route.stops.indexed) {
      final along = _stopAlong[stop.id]!;
      if (i > 0) {
        seconds += segments[i - 1];
        if (along <= profile.last.along) return null;
      }
      profile.add((along: along, seconds: seconds));
    }
    return profile;
  }

  /// Seconds from the first stop at a point on the path.
  static double _secondsAt(double along, List<({double along, double seconds})>? profile) {
    if (profile == null) return along / fallbackSpeedMps;
    final first = profile.first;
    final last = profile.last;
    if (along <= first.along) return (along - first.along) / fallbackSpeedMps;
    if (along >= last.along) return last.seconds + (along - last.along) / fallbackSpeedMps;
    for (var i = 1; i < profile.length; i++) {
      final a = profile[i - 1];
      final b = profile[i];
      if (along <= b.along) {
        final t = (along - a.along) / (b.along - a.along);
        return a.seconds + t * (b.seconds - a.seconds);
      }
    }
    return last.seconds;
  }

  /// Where the bus stands relative to [stopId] on a trip running [direction].
  /// [recordedAt] is the stop time the driver's phone recorded there this
  /// trip, if any.
  Arrival arrivalAt({
    required String stopId,
    required double busLat,
    required double busLng,
    required TripDirection direction,
    DateTime? recordedAt,
    TravelModel? travel,
  }) {
    final stopAlong = _stopAlong[stopId];
    if (stopAlong == null) return const OffRoute();
    final bus = line.project(busLat, busLng);
    if (bus.offRoute > offRouteM) return const OffRoute();

    // Positive while the stop is still ahead in the direction of travel.
    final ahead = direction == TripDirection.toCampus ? stopAlong - bus.along : bus.along - stopAlong;
    if (ahead.abs() <= atStopM) return const ArrivingNow();
    if (ahead < 0 || recordedAt != null) return Passed(recordedAt);
    return Approaching(travelTime(bus.along, stopAlong, travel: travel), ahead);
  }
}
