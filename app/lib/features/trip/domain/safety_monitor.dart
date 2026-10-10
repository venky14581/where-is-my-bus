import 'fix.dart';

enum SafetyEventType { overspeed, offRoute }

/// Something the transport office should know about, noticed on the
/// driver's phone. Sent once per episode, not with every position.
class SafetyEvent {
  const SafetyEvent.overspeed({
    required this.lat,
    required this.lng,
    required int this.speedKmh,
    required int this.limitKmh,
  })  : type = SafetyEventType.overspeed,
        distanceM = null;

  const SafetyEvent.offRoute({required this.lat, required this.lng, required int this.distanceM})
      : type = SafetyEventType.offRoute,
        speedKmh = null,
        limitKmh = null;

  final SafetyEventType type;
  final double lat;
  final double lng;
  final int? speedKmh;
  final int? limitKmh;
  final int? distanceM;
}

/// Watches each good fix for overspeeding and for leaving the route.
///
/// An episode is reported once it has lasted long enough to be real (not a
/// GPS blip), and not again until the bus has been back within limits for a
/// while, so a driver hovering at the limit does not flood the office.
class SafetyMonitor {
  SafetyMonitor({required this.limitKmh, required this.offRouteMetres});

  /// From the office's settings (`settings/safety`).
  final int limitKmh;

  /// How far a point is from the route's road.
  final double Function(double lat, double lng) offRouteMetres;

  static const overspeedFor = Duration(seconds: 10);
  static const offRouteM = 300.0;
  static const offRouteFor = Duration(seconds: 60);

  /// Back to normal for this long before a new episode can be reported.
  static const calmFor = Duration(seconds: 60);

  /// Below the limit by this much counts as back to normal.
  static const calmBelowKmh = 5;
  static const backOnRouteM = 150.0;

  final _speed = _Episode();
  final _route = _Episode();

  List<SafetyEvent> onFix(Fix fix) {
    final events = <SafetyEvent>[];
    final kmh = fix.speedMps * 3.6;
    if (_speed.update(
      at: fix.time,
      bad: kmh > limitKmh,
      calm: kmh <= limitKmh - calmBelowKmh,
      badFor: overspeedFor,
      calmFor: calmFor,
    )) {
      events.add(SafetyEvent.overspeed(lat: fix.lat, lng: fix.lng, speedKmh: kmh.round(), limitKmh: limitKmh));
    }
    final away = offRouteMetres(fix.lat, fix.lng);
    if (_route.update(
      at: fix.time,
      bad: away > offRouteM,
      calm: away < backOnRouteM,
      badFor: offRouteFor,
      calmFor: calmFor,
    )) {
      events.add(SafetyEvent.offRoute(lat: fix.lat, lng: fix.lng, distanceM: away.round()));
    }
    return events;
  }
}

/// One kind of trouble: true from [update] when an episode should be reported.
class _Episode {
  DateTime? _badSince;
  DateTime? _calmSince;
  bool _reported = false;

  bool update({
    required DateTime at,
    required bool bad,
    required bool calm,
    required Duration badFor,
    required Duration calmFor,
  }) {
    if (bad) {
      _calmSince = null;
      _badSince ??= at;
      if (!_reported && at.difference(_badSince!) >= badFor) {
        _reported = true;
        return true;
      }
      return false;
    }
    _badSince = null;
    if (!_reported) return false;
    if (!calm) {
      _calmSince = null;
      return false;
    }
    _calmSince ??= at;
    if (at.difference(_calmSince!) >= calmFor) {
      _reported = false;
      _calmSince = null;
    }
    return false;
  }
}
