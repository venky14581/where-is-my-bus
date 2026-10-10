/// A stop on a route, in travel order towards campus.
class RouteStop {
  const RouteStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.scheduledTime,
    this.distanceFromStartM = 0,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Morning pickup time as `HH:mm`, set by the transport office.
  final String scheduledTime;

  /// Road distance from the first stop, from OSRM.
  final int distanceFromStartM;

  factory RouteStop.fromMap(Map<String, dynamic> data) => RouteStop(
        id: data['id'] as String,
        name: data['name'] as String? ?? '',
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        scheduledTime: data['scheduledTime'] as String? ?? '',
        distanceFromStartM: (data['distanceFromStartM'] as num?)?.toInt() ?? 0,
      );
}

/// A `routes/{routeId}` document.
class BusRoute {
  const BusRoute({
    required this.id,
    required this.name,
    required this.city,
    required this.stops,
    this.path,
  });

  final String id;
  final String name;
  final String city;
  final List<RouteStop> stops;

  /// Road path as a Google encoded polyline. Drawn on the map in Module 4.
  final String? path;

  /// Stops a student can board at. The last stop is the campus.
  List<RouteStop> get pickupStops => stops.isEmpty ? stops : stops.sublist(0, stops.length - 1);

  RouteStop? stopById(String? id) {
    for (final stop in stops) {
      if (stop.id == id) return stop;
    }
    return null;
  }

  factory BusRoute.fromMap(String id, Map<String, dynamic> data) => BusRoute(
        id: id,
        name: data['name'] as String? ?? id,
        city: data['city'] as String? ?? '',
        stops: [
          for (final stop in data['stops'] as List? ?? const [])
            RouteStop.fromMap(Map<String, dynamic>.from(stop as Map)),
        ],
        path: data['path'] as String?,
      );
}

/// A `buses/{busId}` document.
class Bus {
  const Bus({
    required this.id,
    required this.number,
    required this.capacity,
    this.routeId,
    this.driverId,
  });

  final String id;
  final String number;
  final int capacity;
  final String? routeId;

  /// The driver's uid, not their driver ID.
  final String? driverId;

  factory Bus.fromMap(String id, Map<String, dynamic> data) => Bus(
        id: id,
        number: data['number'] as String? ?? id,
        capacity: (data['capacity'] as num?)?.toInt() ?? 0,
        routeId: data['routeId'] as String?,
        driverId: data['driverId'] as String?,
      );
}
