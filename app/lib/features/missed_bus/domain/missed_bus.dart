import '../../../core/geo.dart';
import '../../eta/domain/arrival.dart';
import '../../live/domain/live_bus.dart';
import '../../routes/domain/bus_route.dart';
import '../../trip/domain/trip_plan.dart';

/// A trip running today, as other routes' riders see it.
class RunningTrip {
  const RunningTrip({
    required this.id,
    required this.busId,
    required this.routeId,
    required this.direction,
    this.passHolders,
    this.altHeld = 0,
    this.seatsBooked = 0,
  });

  final String id;
  final String busId;
  final String routeId;
  final TripDirection direction;

  /// Seats kept for the route's own pass holders; null until the server has
  /// counted them.
  final int? passHolders;

  /// Seats held or used by riders from other routes.
  final int altHeld;

  /// Evening seats booked by guests (Module 10).
  final int seatsBooked;
}

enum HoldStatus { held, boarded, cancelled, missed }

/// `trips/{tripId}/holds/{uid}`: a seat held by a rider from another route.
class SeatHold {
  const SeatHold({required this.uid, required this.name, required this.stopId, required this.status});

  final String uid;
  final String name;
  final String stopId;
  final HoldStatus status;
}

/// What the server said to a hold request. See holdSeat in functions/src/holds.ts.
enum HoldResult {
  held,
  full,
  passed,
  notAllowed,
  noPass,
  notRunning,
  badStop,

  /// The phone could not reach the server.
  offline,
}

/// One bus a student who missed theirs could take.
class RideOption {
  const RideOption({
    required this.trip,
    required this.bus,
    required this.route,
    required this.live,
    required this.pickup,
    required this.walkMetres,
    required this.busEta,
    required this.reachable,
    required this.freeSeats,
  });

  final RunningTrip trip;
  final Bus bus;
  final BusRoute route;
  final LiveBus live;

  /// The route stop to walk to. Only official stops are offered: they are
  /// where buses are allowed to stop and pick up safely.
  final RouteStop pickup;

  /// Rough walking distance: straight line plus a share for roads.
  final double walkMetres;

  /// Until the bus reaches [pickup]; zero when it is there now.
  final Duration busEta;

  /// Whether the student can walk there before the bus does.
  final bool reachable;

  /// Seats left for other routes' riders; null while unknown.
  final int? freeSeats;

  Duration get walkTime => Duration(seconds: (walkMetres / MissedBus.walkingSpeedMps).round());
}

abstract final class MissedBus {
  /// Roads are rarely straight: walking distance is about this much longer
  /// than the straight line.
  static const detourFactor = 1.3;

  /// An unhurried walk with a bag, 4.5 km/h.
  static const walkingSpeedMps = 1.25;

  /// Be at the stop this long before the bus.
  static const margin = Duration(minutes: 2);

  /// Further than this to walk, an option is not worth showing.
  static const maxWalkMetres = 5000.0;

  /// The office's choice: routes whose riders [routeId] may carry.
  static bool mayRide({
    required String tripRouteId,
    required String? studentRouteId,
    required Map<String, List<String>> acceptsFrom,
  }) =>
      studentRouteId != null &&
      studentRouteId != tripRouteId &&
      (acceptsFrom[tripRouteId] ?? const []).contains(studentRouteId);

  static int? freeSeats(int capacity, RunningTrip trip) {
    final kept = trip.passHolders;
    if (kept == null) return null;
    // Same sum as spareSeats in functions/src/booking.ts.
    final free = capacity - kept - trip.altHeld - trip.seatsBooked;
    return free < 0 ? 0 : free;
  }

  /// Buses the student may take, each with the best stop to get on at:
  /// the nearest one they can reach before the bus, else simply the nearest.
  /// Where the student already holds a seat ([heldStops], stop by trip),
  /// that stop is kept. Reachable options first, soonest bus first.
  /// [fromLat], [fromLng] is
  /// where the student is, or their usual stop; it never leaves the phone.
  static List<RideOption> options({
    required String? studentRouteId,
    required List<RunningTrip> trips,
    required Map<String, List<String>> acceptsFrom,
    required Map<String, BusRoute> routes,
    required Map<String, Bus> buses,
    required Map<String, LiveBus> live,
    required Map<String, Map<String, DateTime>> stopTimes,
    required double fromLat,
    required double fromLng,
    required DateTime serverNow,
    Map<String, String> heldStops = const {},
  }) {
    final result = <RideOption>[];
    for (final trip in trips) {
      if (!mayRide(tripRouteId: trip.routeId, studentRouteId: studentRouteId, acceptsFrom: acceptsFrom)) continue;
      final route = routes[trip.routeId];
      final bus = buses[trip.busId];
      final position = live[trip.busId];
      if (route == null || bus == null || position == null || position.tripId != trip.id) continue;
      // Without a fresh position there is nothing to time a walk against.
      final state = position.stateAt(serverNow);
      if (state != BusLiveState.live && state != BusLiveState.stale) continue;

      final timeline = RouteTimeline.of(route);
      final recorded = stopTimes[trip.id] ?? const {};
      final candidates = <RideOption>[];
      final order = stopsInTravelOrder(route, trip.direction);
      final held = heldStops[trip.id];
      // A stop time anywhere means every stop up to it is behind the bus,
      // even ones it went past without recording (as on the server).
      final lastRecorded = order.lastIndexWhere((s) => recorded.containsKey(s.id));
      for (final (index, stop) in order.take(order.length - 1).indexed) {
        if (held != null && stop.id != held) continue;
        // The stop just reached still counts for a held seat: the server
        // keeps it while the rider boards there.
        final boardingNow = held != null && index == lastRecorded;
        if (index <= lastRecorded && !boardingNow) continue;
        final arrival = timeline.arrivalAt(
          stopId: stop.id,
          busLat: position.lat,
          busLng: position.lng,
          direction: trip.direction,
          recordedAt: recorded[stop.id],
        );
        final eta = boardingNow ? Duration.zero : switch (arrival) {
          Approaching(:final eta) => eta - serverNow.difference(position.updatedAt),
          ArrivingNow() => Duration.zero,
          _ => null,
        };
        if (eta == null) continue;
        final walk = metresBetween(fromLat, fromLng, stop.lat, stop.lng) * detourFactor;
        if (walk > maxWalkMetres && held == null) continue;
        final busEta = eta.isNegative ? Duration.zero : eta;
        final walkTime = Duration(seconds: (walk / walkingSpeedMps).round());
        candidates.add(RideOption(
          trip: trip,
          bus: bus,
          route: route,
          live: position,
          pickup: stop,
          walkMetres: walk,
          busEta: busEta,
          reachable: walkTime + margin <= busEta,
          freeSeats: freeSeats(bus.capacity, trip),
        ));
      }
      if (candidates.isEmpty) continue;
      final reachable = candidates.where((c) => c.reachable).toList();
      final pool = reachable.isNotEmpty ? reachable : candidates;
      pool.sort((a, b) => a.walkMetres.compareTo(b.walkMetres));
      result.add(pool.first);
    }
    result.sort((a, b) {
      if (a.reachable != b.reachable) return a.reachable ? -1 : 1;
      return a.busEta.compareTo(b.busEta);
    });
    return result;
  }
}
