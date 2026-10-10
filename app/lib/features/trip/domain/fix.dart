/// One GPS reading from the driver's phone.
class Fix {
  const Fix({
    required this.lat,
    required this.lng,
    required this.time,
    this.speedMps = 0,
    this.accuracyM = 0,
    this.heading = 0,
    this.isMocked = false,
  });

  final double lat;
  final double lng;
  final DateTime time;
  final double speedMps;
  final double accuracyM;
  final double heading;

  /// Reported by Android when a fake-GPS app supplies the location.
  final bool isMocked;
}
