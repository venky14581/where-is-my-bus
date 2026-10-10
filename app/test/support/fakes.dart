import 'package:where_is_my_bus/core/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/app.dart';
import 'package:where_is_my_bus/core/settings_store.dart';
import 'package:where_is_my_bus/features/auth/application/auth_providers.dart';
import 'package:where_is_my_bus/features/auth/data/auth_repository.dart';
import 'package:where_is_my_bus/features/auth/domain/app_user.dart';
import 'package:where_is_my_bus/features/auth/domain/auth_failure.dart';
import 'package:where_is_my_bus/features/auth/domain/credentials.dart';
import 'package:where_is_my_bus/features/auth/domain/session.dart';
import 'package:where_is_my_bus/features/alerts/application/alerts_providers.dart';
import 'package:where_is_my_bus/features/alerts/data/alerts_repository.dart';
import 'package:where_is_my_bus/features/alerts/data/push_service.dart';
import 'package:where_is_my_bus/features/alerts/domain/alert_prefs.dart';
import 'package:where_is_my_bus/features/alerts/domain/feed_item.dart';
import 'package:where_is_my_bus/features/booking/application/booking_providers.dart';
import 'package:where_is_my_bus/features/booking/data/booking_repository.dart';
import 'package:where_is_my_bus/features/booking/data/payment_gateway.dart';
import 'package:where_is_my_bus/features/booking/domain/booking.dart';
import 'package:where_is_my_bus/features/eta/application/eta_providers.dart';
import 'package:where_is_my_bus/features/eta/data/stop_times_repository.dart';
import 'package:where_is_my_bus/features/eta/domain/learned_times.dart';
import 'package:where_is_my_bus/features/live/application/live_providers.dart';
import 'package:where_is_my_bus/features/pass/application/pass_providers.dart';
import 'package:where_is_my_bus/features/pass/data/pass_repository.dart';
import 'package:where_is_my_bus/features/live/data/live_repository.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/missed_bus/application/missed_bus_providers.dart';
import 'package:where_is_my_bus/features/missed_bus/data/missed_bus_repository.dart';
import 'package:where_is_my_bus/features/missed_bus/domain/missed_bus.dart';
import 'package:where_is_my_bus/features/routes/application/route_providers.dart';
import 'package:where_is_my_bus/features/routes/data/route_repository.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/safety/application/safety_providers.dart';
import 'package:where_is_my_bus/features/safety/data/safety_repository.dart';
import 'package:where_is_my_bus/features/smart/application/smart_providers.dart';
import 'package:where_is_my_bus/features/smart/data/smart_repository.dart';
import 'package:where_is_my_bus/features/trip/application/trip_controller.dart';

import 'trip_fakes.dart';

class InMemorySettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Account {
  _Account({required this.secret, required this.profile, this.verified = true});

  final String secret;
  AppUser? profile;
  bool verified;
}

/// In-memory stand-in for Firebase that follows the same rules as
/// `FirebaseAuthRepository`: college emails only, driver ID mapped to email.
class FakeAuthRepository implements AuthRepository {
  final _accounts = <String, _Account>{};
  final _changes = StreamController<Session>.broadcast();
  Session _current = const SignedOut();
  String? _currentEmail;
  int signInCalls = 0;

  void addStudent(
    String email,
    String password, {
    String name = 'Asha',
    bool verified = true,
    String? routeId,
    String? stopId,
    bool passValid = false,
    String? passValidUntil,
    int? walkMinutes,
  }) {
    final uid = 'uid-$email';
    _accounts[email] = _Account(
      secret: password,
      verified: verified,
      profile: AppUser(
        uid: uid,
        name: name,
        role: UserRole.student,
        email: email,
        language: 'en',
        routeId: routeId,
        stopId: stopId,
        passValid: passValid,
        passValidUntil: passValidUntil,
        walkMinutes: walkMinutes,
      ),
    );
  }

  void setAlertPrefs(AlertPrefs prefs) {
    final account = _accounts[_currentEmail]!;
    account.profile = account.profile!.copyWith(alerts: prefs);
    _emit();
  }

  void setWalkMinutes(int? minutes) {
    final account = _accounts[_currentEmail]!;
    final p = account.profile!;
    account.profile = AppUser(
      uid: p.uid,
      name: p.name,
      role: p.role,
      email: p.email,
      routeId: p.routeId,
      stopId: p.stopId,
      passValid: p.passValid,
      passValidUntil: p.passValidUntil,
      language: p.language,
      alerts: p.alerts,
      dailyRider: p.dailyRider,
      walkMinutes: minutes,
    );
    _emit();
  }

  /// What a successful `users/{uid}` update does to the session.
  void setHomeStop(String routeId, String stopId) {
    final account = _accounts[_currentEmail]!;
    account.profile = account.profile!.copyWith(routeId: routeId, stopId: stopId, dailyRider: true);
    _emit();
  }

  void setNoDailyBus() {
    final account = _accounts[_currentEmail]!;
    final p = account.profile!;
    account.profile = AppUser(
      uid: p.uid,
      name: p.name,
      role: p.role,
      email: p.email,
      passValid: p.passValid,
      passValidUntil: p.passValidUntil,
      language: p.language,
      alerts: p.alerts,
      dailyRider: false,
    );
    _emit();
  }

  void addDriver(String driverId, String pin, {String name = 'Murugan', String? language}) {
    final email = driverEmailFor(driverId);
    _accounts[email] = _Account(
      secret: pin,
      profile: AppUser(
        uid: 'uid-$driverId',
        name: name,
        role: UserRole.driver,
        driverId: normalizeDriverId(driverId),
        language: language,
      ),
    );
  }

  void addOffice(String email, String password) {
    _accounts[email] = _Account(
      secret: password,
      profile: AppUser(uid: 'uid-$email', name: 'Office', role: UserRole.office, email: email),
    );
  }

  /// Simulates the student opening the link in the verification email.
  void verifyEmail(String email) => _accounts[email]!.verified = true;

  void _emit() {
    final email = _currentEmail;
    final account = email == null ? null : _accounts[email];
    _current = account == null
        ? const SignedOut()
        : SignedIn(
            uid: 'uid-$email',
            email: email!,
            emailVerified: account.verified,
            profile: account.profile,
          );
    _changes.add(_current);
  }

  @override
  Stream<Session> sessions() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signInStudent({required String email, required String password}) async {
    signInCalls++;
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    _signIn(normalized, password);
  }

  @override
  Future<void> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String language,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    if (_accounts.containsKey(normalized)) throw const AuthFailure(AuthFailureCode.emailInUse);
    addStudent(normalized, password, name: name, verified: false);
    _currentEmail = normalized;
    _emit();
  }

  @override
  Future<void> signInDriver({required String driverId, required String pin}) async {
    signInCalls++;
    if (!isValidDriverId(driverId)) throw const AuthFailure(AuthFailureCode.invalidDriverId);
    if (!isValidPin(pin)) throw const AuthFailure(AuthFailureCode.invalidPin);
    _signIn(driverEmailFor(driverId), pin);
  }

  void _signIn(String email, String secret) {
    final account = _accounts[email];
    if (account == null || account.secret != secret) {
      throw const AuthFailure(AuthFailureCode.wrongCredentials);
    }
    _currentEmail = email;
    _emit();
  }

  @override
  Future<void> sendVerificationEmail() async {}

  @override
  Future<bool> refreshEmailVerified() async {
    _emit();
    final current = _current;
    return current is SignedIn && current.emailVerified;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> createStudentProfile({required String name, required String language}) async {
    final account = _accounts[_currentEmail]!;
    account.profile = AppUser(
      uid: 'uid-$_currentEmail',
      name: name,
      role: UserRole.student,
      email: _currentEmail,
      language: language,
    );
    _emit();
  }

  @override
  Future<void> updateLanguage(String languageCode) async {
    final account = _accounts[_currentEmail];
    final profile = account?.profile;
    if (profile == null) return;
    account!.profile = profile.copyWith(language: languageCode);
    _emit();
  }

  @override
  Future<void> signOut() async {
    _currentEmail = null;
    _emit();
  }
}

const testCampus = RouteStop(id: 'campus', name: 'Amrita Campus', lat: 10.9027, lng: 76.9006, scheduledTime: '08:00');

final testRoutes = [
  const BusRoute(id: 'cbe-gandhipuram', name: 'Gandhipuram – Campus', city: 'Coimbatore', stops: [
    RouteStop(id: 'gandhipuram', name: 'Gandhipuram Bus Stand', lat: 11.0183, lng: 76.9672, scheduledTime: '07:00'),
    RouteStop(id: 'ukkadam', name: 'Ukkadam', lat: 10.9886, lng: 76.962, scheduledTime: '07:15'),
    testCampus,
  ]),
  const BusRoute(id: 'pkd-town', name: 'Palakkad – Campus', city: 'Palakkad', stops: [
    RouteStop(id: 'palakkad-stadium', name: 'Palakkad Stadium Bus Stand', lat: 10.776, lng: 76.655, scheduledTime: '06:50'),
    testCampus,
  ]),
];

/// In-memory routes and buses. Saving a stop updates [auth]'s session, like
/// the profile listener does against Firestore.
class FakeRouteRepository implements RouteRepository {
  FakeRouteRepository(this.auth, {List<BusRoute>? routes, this.buses = const []})
      : routes = routes ?? testRoutes;

  final FakeAuthRepository auth;
  final List<BusRoute> routes;
  final List<Bus> buses;

  @override
  Stream<List<BusRoute>> watchRoutes() => Stream.value(routes);

  @override
  Stream<BusRoute?> watchRoute(String routeId) =>
      Stream.value(routes.where((r) => r.id == routeId).firstOrNull);

  @override
  Stream<List<Bus>> watchBuses() => Stream.value(buses);

  @override
  Stream<Bus?> watchBusForRoute(String routeId) =>
      Stream.value(buses.where((b) => b.routeId == routeId).firstOrNull);

  @override
  Stream<Bus?> watchBusForDriver(String driverUid) =>
      Stream.value(buses.where((b) => b.driverId == driverUid).firstOrNull);

  @override
  Future<void> saveHomeStop({required String uid, required String routeId, required String stopId}) async =>
      auth.setHomeStop(routeId, stopId);

  @override
  Future<void> saveNoDailyBus(String uid) async => auth.setNoDailyBus();
}

class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository(this.auth);

  final FakeAuthRepository auth;
  final feed = <FeedItem>[];
  final saved = <AlertPrefs>[];

  @override
  Stream<List<FeedItem>> watchFeed(String routeId) => Stream.value(feed);

  @override
  Future<void> savePrefs(String uid, AlertPrefs prefs) async {
    saved.add(prefs);
    auth.setAlertPrefs(prefs);
  }

  @override
  Future<void> saveWalkMinutes(String uid, int? minutes) async => auth.setWalkMinutes(minutes);
}

class FakePushService implements PushService {
  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<void> register(String uid) async {
    if (!registered.contains(uid)) registered.add(uid);
  }

  @override
  Future<void> unregister(String uid) async => unregistered.add(uid);
}

class FakePassRepository implements PassRepository {
  final secrets = <String, String>{};
  final scanned = <String>[];
  ScanOutcome Function(String code) decide = (_) => const ScanOutcome(ScanResult.boarded, name: 'Asha');

  @override
  Stream<String?> watchSecret(String uid) => Stream.value(secrets[uid]);

  @override
  Future<ScanOutcome> scan({required String tripId, required String code}) async {
    scanned.add(code);
    return decide(code);
  }

  @override
  Stream<int> watchBoardedCount(String tripId) =>
      Stream.value(scanned.where((c) => decide(c).result == ScanResult.boarded).length);
}

/// Stands in for the camera: tests call [emit] to "scan" a code.
class FakeScanner {
  void Function(String code)? _onCode;

  void emit(String code) => _onCode?.call(code);

  ScannerBuilder get builder => (context, onCode) {
        _onCode = onCode;
        return const ColoredBox(color: Colors.black);
      };
}

class FakeStopTimesRepository implements StopTimesRepository {
  final byTrip = <String, Map<String, DateTime>>{};

  @override
  Stream<Map<String, DateTime>> watch(String tripId) => Stream.value(byTrip[tripId] ?? const {});
}

/// Live bus positions the test sets by hand.
class FakeLiveRepository implements LiveRepository {
  final _buses = <String, LiveBus>{};
  final _changes = StreamController<void>.broadcast();

  void put(LiveBus bus) {
    _buses[bus.busId] = bus;
    _changes.add(null);
  }

  @override
  Stream<LiveBus?> watchBus(String busId) async* {
    yield _buses[busId];
    await for (final _ in _changes.stream) {
      yield _buses[busId];
    }
  }

  @override
  Stream<List<LiveBus>> watchAll() async* {
    yield _buses.values.toList();
    await for (final _ in _changes.stream) {
      yield _buses.values.toList();
    }
  }

  @override
  Stream<Duration> serverTimeOffset() => Stream.value(Duration.zero);
}

/// Running trips, route access and seat holds, all changed by hand.
class FakeMissedBusRepository implements MissedBusRepository {
  final trips = <RunningTrip>[];
  final access = <String, List<String>>{};

  /// Holds by trip, then student.
  final holds = <String, Map<String, SeatHold>>{};
  HoldResult nextResult = HoldResult.held;
  final requests = <({String tripId, String stopId})>[];

  /// Who [hold] holds the seat for.
  String holder = '';
  final _changes = StreamController<void>.broadcast();

  void changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<RunningTrip>> watchRunningTrips(String date) => _watch(() => [...trips]);

  @override
  Stream<Map<String, List<String>>> watchRouteAccess() => _watch(() => {...access});

  @override
  Stream<SeatHold?> watchHold({required String tripId, required String uid}) => _watch(() => holds[tripId]?[uid]);

  @override
  Stream<List<SeatHold>> watchWaitingHolds(String tripId) =>
      _watch(() => [...?holds[tripId]?.values.where((h) => h.status == HoldStatus.held)]);

  @override
  Future<HoldResult> hold({required String tripId, required String stopId}) async {
    requests.add((tripId: tripId, stopId: stopId));
    if (nextResult == HoldResult.held) {
      (holds[tripId] ??= {})[holder] = SeatHold(uid: holder, name: 'Asha', stopId: stopId, status: HoldStatus.held);
      changed();
    }
    return nextResult;
  }

  @override
  Future<void> cancel(String tripId) async {
    final mine = holds[tripId]?[holder];
    if (mine == null) return;
    holds[tripId]![holder] = SeatHold(uid: holder, name: mine.name, stopId: mine.stopId, status: HoldStatus.cancelled);
    changed();
  }
}

/// Evening trips and bookings in memory. Booking makes an unpaid booking;
/// paying confirms it with a ticket token, as the server does.
class FakeBookingRepository implements BookingRepository {
  final trips = <EveningTrip>[];
  final bookings = <String, Booking>{};
  BookResult nextResult = BookResult.booked;
  final requests = <({String tripId, String stopId})>[];
  final cancelled = <String>[];
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<EveningTrip>> watchEveningTrips(List<String> dates) =>
      _watch(() => [for (final t in trips) if (dates.contains(t.date)) t]);

  @override
  Stream<List<Booking>> watchMyBookings(String uid) => _watch(() => bookings.values.toList());

  @override
  Future<BookOutcome> book({required String tripId, required String stopId}) async {
    requests.add((tripId: tripId, stopId: stopId));
    if (nextResult != BookResult.booked) return BookOutcome(nextResult);
    final trip = trips.firstWhere((t) => t.id == tripId);
    final id = '${tripId}_me';
    bookings[id] = Booking(
      id: id,
      tripId: tripId,
      routeId: trip.routeId,
      busId: trip.busId,
      date: trip.date,
      departsAt: trip.departsAt,
      stopId: stopId,
      fare: trip.guestFare ?? 0,
      status: BookingStatus.pendingPayment,
    );
    _changes.add(null);
    return BookOutcome(BookResult.booked, bookingId: id, payment: const PaymentInfo(mode: PaymentMode.demo));
  }

  void _set(String id, BookingStatus status, {String? token}) {
    final b = bookings[id]!;
    bookings[id] = Booking(
      id: b.id,
      tripId: b.tripId,
      routeId: b.routeId,
      busId: b.busId,
      date: b.date,
      departsAt: b.departsAt,
      stopId: b.stopId,
      fare: b.fare,
      status: status,
      ticketToken: token ?? b.ticketToken,
    );
    _changes.add(null);
  }

  @override
  Future<PayResult> pay({required String bookingId, required PaymentProof proof}) async {
    _set(bookingId, BookingStatus.confirmed, token: 'tok');
    return PayResult.confirmed;
  }

  @override
  Future<void> cancel(String bookingId) async {
    cancelled.add(bookingId);
    _set(bookingId, BookingStatus.cancelled);
  }
}

/// Learned times, today's conditions, trip seat counts and Not riding marks
/// in memory. setNotRiding answers [nextNotRiding] and, when that is a
/// change, records it.
class FakeSmartRepository implements SmartRepository {
  final learned = <String, LearnedTimes>{};
  final conditions = <String, Conditions>{};
  final seats = <String, TripSeats>{};
  final notRiding = <String>{};
  final requests = <({String tripId, bool notRiding})>[];
  NotRidingResult? nextNotRiding;
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  /// Sends the current values again, after a test changes them.
  void emit() => _changes.add(null);

  @override
  Stream<LearnedTimes?> watchLearned(String routeId) => _watch(() => learned[routeId]);

  @override
  Stream<Conditions?> watchConditions(String date) => _watch(() => conditions[date]);

  @override
  Stream<TripSeats?> watchTripSeats(String tripId) => _watch(() => seats[tripId]);

  @override
  Stream<bool> watchNotRiding({required String tripId, required String uid}) => _watch(() => notRiding.contains(tripId));

  @override
  Future<NotRidingResult> setNotRiding({required String tripId, required bool notRiding}) async {
    requests.add((tripId: tripId, notRiding: notRiding));
    final answer = nextNotRiding ?? (notRiding ? NotRidingResult.notRiding : NotRidingResult.riding);
    if (answer == NotRidingResult.notRiding) this.notRiding.add(tripId);
    if (answer == NotRidingResult.riding) this.notRiding.remove(tripId);
    _changes.add(null);
    return answer;
  }
}

/// Records SOS presses and trip shares; answers with [sos] and [share].
class FakeSafetyRepository implements SafetyRepository {
  SosResult sos = SosResult.sent;
  ShareResult share = ShareResult.shared;
  var sosCount = 0;
  var shareCount = 0;

  @override
  Future<SosResult> sendSos() async {
    sosCount++;
    return sos;
  }

  @override
  Future<({ShareResult result, String? token})> shareTrip() async {
    shareCount++;
    return (result: share, token: share == ShareResult.shared ? 'tok123' : null);
  }
}

/// Pays at once, or backs out when [backOut] is set.
class FakePaymentGateway implements PaymentGateway {
  bool backOut = false;
  final charged = <num>[];

  @override
  Future<PaymentProof?> pay(
    BuildContext context, {
    required PaymentInfo info,
    required num fare,
    required String description,
    String? email,
  }) async {
    if (backOut) return null;
    charged.add(fare);
    return const DemoPaymentProof();
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository auth, {
  InMemorySettingsStore? settings,
  FakeRouteRepository? routes,
  FakeTripRepository? trips,
  FakeLocationSource? location,
  FakeLiveRepository? live,
  FakeStopTimesRepository? stopTimes,
  FakeAlertsRepository? alerts,
  FakePushService? push,
  FakePassRepository? passes,
  FakeScanner? scanner,
  FakeMissedBusRepository? missedBus,
  Locate? locate,
  FakeBookingRepository? bookings,
  FakePaymentGateway? payments,
  FakeSmartRepository? smart,
  FakeSafetyRepository? safety,
}) async {
  // A phone-sized surface so layouts match what students and drivers see.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      settingsStoreProvider.overrideWithValue(settings ?? InMemorySettingsStore()),
      routeRepositoryProvider.overrideWithValue(routes ?? FakeRouteRepository(auth)),
      tripRepositoryProvider.overrideWithValue(trips ?? FakeTripRepository()),
      locationSourceProvider.overrideWithValue(location ?? FakeLocationSource()),
      tripKeepAliveProvider.overrideWithValue(FakeKeepAlive()),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 10, 7)),
      liveRepositoryProvider.overrideWithValue(live ?? FakeLiveRepository()),
      mapTilesEnabledProvider.overrideWithValue(false),
      stopTimesRepositoryProvider.overrideWithValue(stopTimes ?? FakeStopTimesRepository()),
      alertsRepositoryProvider.overrideWithValue(alerts ?? FakeAlertsRepository(auth)),
      pushServiceProvider.overrideWithValue(push ?? FakePushService()),
      passRepositoryProvider.overrideWithValue(passes ?? FakePassRepository()),
      scannerBuilderProvider.overrideWithValue((scanner ?? FakeScanner()).builder),
      missedBusRepositoryProvider.overrideWithValue(missedBus ?? FakeMissedBusRepository()),
      locateProvider.overrideWithValue(locate ?? () async => null),
      bookingRepositoryProvider.overrideWithValue(bookings ?? FakeBookingRepository()),
      paymentGatewayProvider.overrideWithValue(payments ?? FakePaymentGateway()),
      smartRepositoryProvider.overrideWithValue(smart ?? FakeSmartRepository()),
      safetyRepositoryProvider.overrideWithValue(safety ?? FakeSafetyRepository()),
    ],
    child: const WhereIsMyBusApp(),
  ));
  await tester.pumpAndSettle();
}
