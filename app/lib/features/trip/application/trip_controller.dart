import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/settings_store.dart';
import '../../routes/domain/bus_route.dart';
import '../data/active_trip_store.dart';
import '../data/location_source.dart';
import '../data/trip_keep_alive.dart';
import '../data/trip_repository.dart';
import '../domain/fix.dart';
import '../domain/fix_filter.dart';
import '../domain/stop_detector.dart';
import '../domain/trip_plan.dart';

enum TripPhase { idle, starting, running }

enum TripProblem { locationOff, permissionDenied, permissionDeniedForever, startFailed }

@immutable
class TripState {
  const TripState({
    this.phase = TripPhase.idle,
    this.tripId,
    this.direction,
    this.lastSentAt,
    this.online = true,
    this.nextStop,
    this.reachedCount = 0,
    this.totalStops = 0,
    this.problem,
    this.mockDetected = false,
  });

  final TripPhase phase;

  /// Set while a trip runs; the pass scanner needs it.
  final String? tripId;
  final TripDirection? direction;

  /// When the last position reached the server (phone clock).
  final DateTime? lastSentAt;

  final bool online;
  final RouteStop? nextStop;
  final int reachedCount;
  final int totalStops;
  final TripProblem? problem;

  /// A fake-GPS reading arrived. Nothing is sent until real readings resume.
  final bool mockDetected;

  TripState copyWith({
    DateTime? lastSentAt,
    bool? online,
    RouteStop? nextStop,
    int? reachedCount,
    bool? mockDetected,
  }) =>
      TripState(
        phase: phase,
        tripId: tripId,
        direction: direction,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        online: online ?? this.online,
        nextStop: nextStop ?? this.nextStop,
        reachedCount: reachedCount ?? this.reachedCount,
        totalStops: totalStops,
        problem: problem,
        mockDetected: mockDetected ?? this.mockDetected,
      );
}

/// Runs the driver's trip: start, send the bus position at most every
/// [minSendInterval], record stop times, end.
class TripController extends Notifier<TripState> {
  static const minSendInterval = Duration(milliseconds: 2500);

  StreamSubscription<Fix>? _fixes;
  StreamSubscription<bool>? _connection;
  FixFilter _filter = FixFilter();
  StopDetector? _stops;
  ActiveTrip? _active;
  Fix? _pending;
  DateTime? _lastSendAt;

  /// Whether `live/{busId}` will flip to offline if this connection drops.
  bool _disconnectArmed = false;

  TripRepository get _repo => ref.read(tripRepositoryProvider);
  ActiveTripStore get _store => ref.read(activeTripStoreProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  TripState build() {
    ref.onDispose(_stopListening);
    return const TripState();
  }

  /// Starts a trip on [bus], or picks up the one already running from a
  /// previous launch of the app.
  Future<void> start({required Bus bus, required BusRoute route, required String driverUid}) async {
    if (state.phase != TripPhase.idle) return;
    state = const TripState(phase: TripPhase.starting);

    final location = ref.read(locationSourceProvider);
    final access = await location.ensureAccess();
    if (access != LocationAccess.granted) {
      state = TripState(problem: switch (access) {
        LocationAccess.serviceDisabled => TripProblem.locationOff,
        LocationAccess.deniedForever => TripProblem.permissionDeniedForever,
        _ => TripProblem.permissionDenied,
      });
      return;
    }

    final now = _now();
    final direction = directionAt(now);
    final tripId = tripIdFor(busId: bus.id, local: now, direction: direction);
    final saved = _store.read();
    if (saved != null && saved.tripId != tripId) {
      // A trip left running from earlier, e.g. the morning trip never ended.
      unawaited(_repo.endTrip(saved.tripId).catchError((_) {}));
    }

    try {
      await _repo.startTrip(TripStart(
        tripId: tripId,
        busId: bus.id,
        routeId: route.id,
        driverUid: driverUid,
        date: tripDate(now),
        direction: direction,
      ));
    } catch (_) {
      state = const TripState(problem: TripProblem.startFailed);
      return;
    }

    final active = ActiveTrip(
      tripId: tripId,
      busId: bus.id,
      routeId: route.id,
      direction: direction,
      reached: saved?.tripId == tripId ? saved!.reached : const [],
    );
    await _store.save(active);
    await ref
        .read(tripKeepAliveProvider)
        .start(title: bus.number, text: route.name)
        .catchError((_) {}); // tracking still works in the foreground

    _begin(active, route, location);
  }

  /// The trip saved on the phone, if it belongs to [busId]. The driver home
  /// uses it to resume tracking after the app was closed mid-trip.
  ActiveTrip? savedTripFor(String busId) {
    final saved = _store.read();
    return saved?.busId == busId ? saved : null;
  }

  void _begin(ActiveTrip active, BusRoute route, LocationSource location) {
    _active = active;
    _filter = FixFilter();
    _pending = null;
    _lastSendAt = null;
    final stops = StopDetector(stopsInTravelOrder(route, active.direction), reached: active.reached);
    _stops = stops;
    state = TripState(
      phase: TripPhase.running,
      tripId: active.tripId,
      direction: active.direction,
      nextStop: stops.nextStop,
      reachedCount: stops.reached.length,
      totalStops: stops.stops.length,
    );
    _connection = _repo.connection().listen(_onConnection);
    _fixes = location.fixes(route: route, direction: active.direction).listen(_onFix);
  }

  void _onConnection(bool online) {
    final active = _active;
    if (active == null) return;
    state = state.copyWith(online: online);
    if (!online) {
      _disconnectArmed = false; // the server already fired or dropped it
      return;
    }
    final pending = _pending;
    if (pending != null) _send(pending);
  }

  void _onFix(Fix fix) {
    final active = _active;
    final stops = _stops;
    if (active == null || stops == null) return;

    switch (_filter.check(fix)) {
      case FixVerdict.mocked:
        state = state.copyWith(mockDetected: true);
        return;
      case FixVerdict.inaccurate || FixVerdict.impossibleJump:
        return;
      case FixVerdict.accepted:
        if (state.mockDetected) state = state.copyWith(mockDetected: false);
    }

    final arrived = stops.onFix(fix);
    if (arrived.isNotEmpty) {
      for (final stop in arrived) {
        // Queued by Firestore while offline; arrivedAt keeps the real time.
        unawaited(_repo
            .recordStopArrival(tripId: active.tripId, stopId: stop.id, at: fix.time)
            .catchError((_) {}));
      }
      _active = active.withReached(stops.reached);
      unawaited(_store.save(_active!));
      state = TripState(
        phase: state.phase,
        tripId: state.tripId,
        direction: state.direction,
        lastSentAt: state.lastSentAt,
        online: state.online,
        nextStop: stops.nextStop, // may become null at the last stop
        reachedCount: stops.reached.length,
        totalStops: state.totalStops,
      );
    }

    final last = _lastSendAt;
    if (last != null && _now().difference(last) < minSendInterval) return;
    if (!state.online) {
      // Keep only the newest point; it goes out when the signal returns.
      _pending = fix;
      return;
    }
    _send(fix);
  }

  void _send(Fix fix) {
    final active = _active;
    if (active == null) return;
    _pending = null;
    _lastSendAt = _now();
    _repo.publishPosition(busId: active.busId, tripId: active.tripId, fix: fix).then((_) {
      if (_active?.tripId != active.tripId) return;
      state = state.copyWith(lastSentAt: _now());
      // Only after a position exists: the rules refuse an offline marker
      // for a bus with no lat and lng, e.g. on its very first trip.
      if (!_disconnectArmed) {
        _disconnectArmed = true;
        _repo.armDisconnect(active.busId).catchError((_) => _disconnectArmed = false);
      }
    }, onError: (Object _) => _pending ??= fix);
  }

  /// Tells the route's riders the bus is late or has broken down. Returns
  /// false when there is no trip running or the report could not be sent.
  Future<bool> report(TripIssue issue) async {
    final active = _active;
    if (active == null) return false;
    try {
      // Waits for the server so the driver only sees "told" when it is true.
      await _repo.reportIssue(tripId: active.tripId, issue: issue).timeout(const Duration(seconds: 15));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> end() async {
    final active = _active;
    if (state.phase != TripPhase.running || active == null) return;
    _stopListening();
    // Not awaited: both writes queue while offline and must not keep the
    // driver waiting at the end of the route.
    unawaited(_repo.markLiveEnded(busId: active.busId, tripId: active.tripId).catchError((_) {}));
    unawaited(_repo.endTrip(active.tripId).catchError((_) {}));
    await _store.clear();
    await ref.read(tripKeepAliveProvider).stop().catchError((_) {});
    state = const TripState();
  }

  void _stopListening() {
    _fixes?.cancel();
    _connection?.cancel();
    _fixes = null;
    _connection = null;
    _active = null;
    _stops = null;
    _pending = null;
    _disconnectArmed = false;
  }
}

/// Debug builds only: `--dart-define=SIMULATE_DRIVE=true` replaces the GPS
/// with a bus driving the route.
const _simulateDrive = !kReleaseMode && bool.fromEnvironment('SIMULATE_DRIVE');

final locationSourceProvider = Provider<LocationSource>(
  (ref) => _simulateDrive ? SimulatedDrive() : DeviceLocationSource(),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => FirebaseTripRepository(FirebaseFirestore.instance, FirebaseDatabase.instance),
);

final tripKeepAliveProvider = Provider<TripKeepAlive>((ref) => ForegroundServiceKeepAlive());

final activeTripStoreProvider = Provider<ActiveTripStore>(
  (ref) => ActiveTripStore(ref.watch(settingsStoreProvider)),
);

final tripControllerProvider = NotifierProvider<TripController, TripState>(TripController.new);
