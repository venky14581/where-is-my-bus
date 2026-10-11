import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase_bootstrap.dart';

import '../domain/booking.dart';

abstract interface class BookingRepository {
  /// Evening trips on [dates] (YYYY-MM-DD), every route.
  Stream<List<EveningTrip>> watchEveningTrips(List<String> dates);

  /// The student's bookings, newest trip first.
  Stream<List<Booking>> watchMyBookings(String uid);

  /// Asks the server for a seat on [tripId], getting off at [stopId].
  Future<BookOutcome> book({required String tripId, required String stopId});

  Future<PayResult> pay({required String bookingId, required PaymentProof proof});

  /// Gives up an unpaid booking.
  Future<void> cancel(String bookingId);
}

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

  @override
  Stream<List<EveningTrip>> watchEveningTrips(List<String> dates) => _db
      .collection('trips')
      .where('direction', isEqualTo: 'fromCampus')
      .where('date', whereIn: dates)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs) ?_tripFrom(doc.id, doc.data()),
          ]);

  static EveningTrip? _tripFrom(String id, Map<String, dynamic> d) {
    final departsAt = _time(d['departsAt']);
    final opens = _time(d['bookingOpensAt']);
    final closes = _time(d['bookingClosesAt']);
    // Trips a driver started without the scheduler have nothing to book.
    if (departsAt == null || opens == null || closes == null) return null;
    return EveningTrip(
      id: id,
      busId: d['busId'] as String? ?? '',
      routeId: d['routeId'] as String? ?? '',
      date: d['date'] as String? ?? '',
      status: d['status'] as String? ?? 'scheduled',
      departsAt: departsAt,
      bookingOpensAt: opens,
      bookingClosesAt: closes,
      capacity: (d['capacity'] as num?)?.toInt() ?? 0,
      passHolders: (d['passHolders'] as num?)?.toInt() ?? 0,
      altHeld: (d['altHeld'] as num?)?.toInt() ?? 0,
      seatsBooked: (d['seatsBooked'] as num?)?.toInt() ?? 0,
      notRiding: (d['notRiding'] as num?)?.toInt() ?? 0,
      guestFare: d['guestFare'] as num?,
    );
  }

  @override
  Stream<List<Booking>> watchMyBookings(String uid) =>
      _db.collection('bookings').where('uid', isEqualTo: uid).snapshots().map((snap) => [
            for (final doc in snap.docs) ?_bookingFrom(doc.id, doc.data()),
          ]..sort((a, b) => b.departsAt.compareTo(a.departsAt)));

  static Booking? _bookingFrom(String id, Map<String, dynamic> d) {
    final status = BookingStatus.values.where((s) => s.name == d['status']).firstOrNull;
    final departsAt = _time(d['departsAt']);
    if (status == null || departsAt == null) return null;
    return Booking(
      id: id,
      tripId: d['tripId'] as String? ?? '',
      routeId: d['routeId'] as String? ?? '',
      busId: d['busId'] as String? ?? '',
      date: d['date'] as String? ?? '',
      departsAt: departsAt,
      stopId: d['stopId'] as String? ?? '',
      fare: d['fare'] as num? ?? 0,
      status: status,
      expiresAt: _time(d['expiresAt']),
      ticketToken: d['ticketToken'] as String?,
      payment: PaymentInfo.fromMap(d['payment']),
    );
  }

  HttpsCallable _callable(String name) =>
      _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: callTimeout(const Duration(seconds: 20))));

  static bool _isOffline(FirebaseFunctionsException e) =>
      e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'internal';

  @override
  Future<BookOutcome> book({required String tripId, required String stopId}) async {
    try {
      final response = await _callable('bookSeat').call<Map<String, dynamic>>({'tripId': tripId, 'stopId': stopId});
      final data = response.data;
      final result = BookResult.values.where((r) => r.name == data['result']).firstOrNull ?? BookResult.closed;
      return BookOutcome(
        result,
        bookingId: data['bookingId'] as String?,
        payment: data['payment'] == null ? null : PaymentInfo.fromMap(data['payment']),
      );
    } on FirebaseFunctionsException catch (e) {
      if (_isOffline(e)) return const BookOutcome(BookResult.offline);
      rethrow;
    }
  }

  @override
  Future<PayResult> pay({required String bookingId, required PaymentProof proof}) async {
    try {
      final response = await _callable('payBooking').call<Map<String, dynamic>>({
        'bookingId': bookingId,
        ...switch (proof) {
          DemoPaymentProof() => {'demo': true},
          RazorpayPaymentProof(:final paymentId, :final signature) => {
              'razorpayPaymentId': paymentId,
              'razorpaySignature': signature,
            },
        },
      });
      return PayResult.values.where((r) => r.name == response.data['result']).firstOrNull ?? PayResult.invalidPayment;
    } on FirebaseFunctionsException catch (e) {
      if (_isOffline(e)) return PayResult.offline;
      rethrow;
    }
  }

  @override
  Future<void> cancel(String bookingId) => _callable('cancelBooking').call<Map<String, dynamic>>({'bookingId': bookingId});
}
