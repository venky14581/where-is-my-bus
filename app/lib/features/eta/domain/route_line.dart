import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../core/geo.dart';

/// Where a point falls along a route's road path.
class Projection {
  const Projection({required this.along, required this.offRoute});

  /// Metres along the path from its start.
  final double along;

  /// Metres from the point to the nearest part of the path.
  final double offRoute;
}

/// A route's road path with distances along it, for placing the bus and the
/// stops on one scale.
class RouteLine {
  RouteLine(this.points) : _cumulative = _cumulativeOf(points);

  final List<LatLng> points;
  final List<double> _cumulative;

  double get length => _cumulative.isEmpty ? 0 : _cumulative.last;

  static List<double> _cumulativeOf(List<LatLng> points) {
    final result = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        total += metresBetween(points[i - 1].latitude, points[i - 1].longitude, points[i].latitude, points[i].longitude);
      }
      result.add(total);
    }
    return result;
  }

  /// The nearest point on the path to ([lat], [lng]). Uses a flat-earth
  /// approximation per segment, which is accurate to well under a metre at
  /// the scale of a road segment.
  Projection project(double lat, double lng) {
    if (points.isEmpty) return const Projection(along: 0, offRoute: double.infinity);
    if (points.length == 1) {
      return Projection(along: 0, offRoute: metresBetween(lat, lng, points[0].latitude, points[0].longitude));
    }
    final metresPerDegLat = 110540.0;
    final metresPerDegLng = 111320.0 * math.cos(lat * math.pi / 180);

    var best = const Projection(along: 0, offRoute: double.infinity);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      // Segment and point in metres, relative to a.
      final bx = (b.longitude - a.longitude) * metresPerDegLng;
      final by = (b.latitude - a.latitude) * metresPerDegLat;
      final px = (lng - a.longitude) * metresPerDegLng;
      final py = (lat - a.latitude) * metresPerDegLat;
      final lengthSq = bx * bx + by * by;
      final t = lengthSq == 0 ? 0.0 : ((px * bx + py * by) / lengthSq).clamp(0.0, 1.0);
      final dx = px - t * bx;
      final dy = py - t * by;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < best.offRoute) {
        final segment = _cumulative[i + 1] - _cumulative[i];
        best = Projection(along: _cumulative[i] + t * segment, offRoute: distance);
      }
    }
    return best;
  }
}
