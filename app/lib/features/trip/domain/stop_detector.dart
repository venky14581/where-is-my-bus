import '../../../core/geo.dart';
import '../../routes/domain/bus_route.dart';
import 'fix.dart';

/// Notices when the bus reaches each stop, from the stream of good fixes.
class StopDetector {
  StopDetector(this.stops, {Iterable<String> reached = const [], this.radiusM = 80})
      : _reached = {...reached};

  /// In travel order for this trip.
  final List<RouteStop> stops;

  /// Close enough to count as at the stop: a bus bay plus GPS error.
  final double radiusM;

  final Set<String> _reached;

  Set<String> get reached => Set.unmodifiable(_reached);

  /// The first stop after the furthest one reached, or null at the end.
  RouteStop? get nextStop {
    var furthest = -1;
    for (var i = 0; i < stops.length; i++) {
      if (_reached.contains(stops[i].id)) furthest = i;
    }
    return furthest + 1 < stops.length ? stops[furthest + 1] : null;
  }

  /// Stops reached for the first time at this fix, in travel order. A stop
  /// the bus drove past without coming close is never reported.
  List<RouteStop> onFix(Fix fix) {
    final arrived = <RouteStop>[];
    for (final stop in stops) {
      if (_reached.contains(stop.id)) continue;
      if (metresBetween(fix.lat, fix.lng, stop.lat, stop.lng) <= radiusM) {
        _reached.add(stop.id);
        arrived.add(stop);
      }
    }
    return arrived;
  }
}
