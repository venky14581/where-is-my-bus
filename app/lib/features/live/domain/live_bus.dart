/// What a student should make of a bus position.
enum BusLiveState {
  /// Updated within the last [LiveBus.staleAfter].
  live,

  /// The trip is running but nothing new has arrived for a while: weak
  /// signal on the driver's phone. Shown grey with the last update time.
  stale,

  /// The driver's phone dropped off the network; the server marked it.
  offline,

  /// No trip now: ended, never started today, or left over from earlier.
  notRunning,
}

/// A `live/{busId}` node in the Realtime Database.
class LiveBus {
  const LiveBus({
    required this.busId,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    required this.status,
    this.tripId,
    this.speedMps = 0,
    this.heading = 0,
  });

  /// Positions arrive every 3 seconds; ten missed in a row means weak signal.
  static const staleAfter = Duration(seconds: 30);

  /// A position this old is from an earlier trip, even if never ended.
  static const notRunningAfter = Duration(hours: 2);

  final String busId;
  final double lat;
  final double lng;

  /// Server time of the last write.
  final DateTime updatedAt;

  /// `running`, `offline` or `ended`.
  final String status;
  final String? tripId;
  final double speedMps;
  final double heading;

  BusLiveState stateAt(DateTime serverNow) {
    if (status == 'ended') return BusLiveState.notRunning;
    final age = serverNow.difference(updatedAt);
    if (age > notRunningAfter) return BusLiveState.notRunning;
    if (status == 'offline') return BusLiveState.offline;
    if (age > staleAfter) return BusLiveState.stale;
    return BusLiveState.live;
  }

  /// Null for anything malformed, which is then treated as "no bus".
  static LiveBus? tryFromMap(String busId, Object? value) {
    if (value is! Map) return null;
    final lat = value['lat'];
    final lng = value['lng'];
    final updatedAt = value['updatedAt'];
    final status = value['status'];
    if (lat is! num || lng is! num || updatedAt is! num || status is! String) return null;
    return LiveBus(
      busId: busId,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt()),
      status: status,
      tripId: value['tripId'] as String?,
      speedMps: (value['speed'] as num?)?.toDouble() ?? 0,
      heading: (value['heading'] as num?)?.toDouble() ?? 0,
    );
  }
}
