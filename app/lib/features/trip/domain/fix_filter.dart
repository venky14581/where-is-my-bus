import '../../../core/geo.dart';
import 'fix.dart';

enum FixVerdict { accepted, mocked, inaccurate, impossibleJump }

/// Decides which GPS readings are good enough to show students.
///
/// Rejects fake-GPS readings, readings too vague to place the bus on the
/// road, and readings the bus could not have reached since the last good one.
class FixFilter {
  /// Worse than this and the bus could be on the wrong road.
  static const maxAccuracyM = 100.0;

  /// About 120 km/h; no college bus goes faster.
  static const maxSpeedMps = 33.0;

  /// After this many jumps in a row the old fix is the wrong one (for example
  /// the first fix of the day came from a stale cell tower), so start over.
  static const jumpsBeforeReset = 5;

  Fix? _last;
  int _jumpsInARow = 0;

  FixVerdict check(Fix fix) {
    if (fix.isMocked) return FixVerdict.mocked;
    if (fix.accuracyM > maxAccuracyM) return FixVerdict.inaccurate;

    final last = _last;
    if (last != null && _isJump(last, fix) && ++_jumpsInARow < jumpsBeforeReset) {
      return FixVerdict.impossibleJump;
    }
    _jumpsInARow = 0;
    _last = fix;
    return FixVerdict.accepted;
  }

  bool _isJump(Fix from, Fix to) {
    final metres = metresBetween(from.lat, from.lng, to.lat, to.lng);
    // Both readings can be off by their accuracy, so only count the rest.
    final travelled = metres - from.accuracyM - to.accuracyM;
    if (travelled <= 0) return false;
    final seconds = to.time.difference(from.time).inMilliseconds / 1000;
    return seconds <= 0 || travelled / seconds > maxSpeedMps;
  }
}
