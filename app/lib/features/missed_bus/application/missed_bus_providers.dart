import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/firebase_bootstrap.dart';
import '../data/missed_bus_repository.dart';
import '../domain/missed_bus.dart';
import '../domain/public_transport.dart';

final missedBusRepositoryProvider = Provider<MissedBusRepository>(
  (ref) => FirebaseMissedBusRepository(FirebaseFirestore.instance, FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final runningTripsProvider = StreamProvider.autoDispose.family<List<RunningTrip>, String>(
  (ref, date) => ref.watch(missedBusRepositoryProvider).watchRunningTrips(date),
);

final timetableProvider = StreamProvider.autoDispose.family<List<PublicDeparture>, String>(
  (ref, routeId) => ref.watch(missedBusRepositoryProvider).watchTimetable(routeId),
);

final routeAccessProvider = StreamProvider.autoDispose<Map<String, List<String>>>(
  (ref) => ref.watch(missedBusRepositoryProvider).watchRouteAccess(),
);

final seatHoldProvider = StreamProvider.autoDispose.family<SeatHold?, ({String tripId, String uid})>(
  (ref, key) => ref.watch(missedBusRepositoryProvider).watchHold(tripId: key.tripId, uid: key.uid),
);

final waitingHoldsProvider = StreamProvider.autoDispose.family<List<SeatHold>, String>(
  (ref, tripId) => ref.watch(missedBusRepositoryProvider).watchWaitingHolds(tripId),
);

/// Where the student is right now, read once when they ask for help. Stays
/// on the phone: it only picks the nearest stop. Null without permission,
/// with location off, or after 10 seconds without a fix.
typedef Locate = Future<LatLng?> Function();

final locateProvider = Provider<Locate>((ref) => () async {
      try {
        if (!await Geolocator.isLocationServiceEnabled()) return null;
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        return LatLng(p.latitude, p.longitude);
      } catch (_) {
        return null;
      }
    });

final studentHereProvider = FutureProvider.autoDispose<LatLng?>((ref) => ref.watch(locateProvider)());
