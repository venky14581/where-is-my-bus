import '../../routes/domain/bus_route.dart';

enum TripDirection {
  /// Morning: from the first stop to the campus.
  toCampus,

  /// Evening: from the campus back along the route.
  fromCampus,
}

/// Morning trips run before noon. The driver does not have to choose.
TripDirection directionAt(DateTime local) =>
    local.hour < 12 ? TripDirection.toCampus : TripDirection.fromCampus;

String tripDate(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

/// One trip per bus, day and direction. Starting again the same morning
/// resumes that trip instead of creating a second one.
String tripIdFor({required String busId, required DateTime local, required TripDirection direction}) =>
    '${tripDate(local)}_${busId}_${direction.name}';

List<RouteStop> stopsInTravelOrder(BusRoute route, TripDirection direction) =>
    direction == TripDirection.toCampus ? route.stops : route.stops.reversed.toList();
