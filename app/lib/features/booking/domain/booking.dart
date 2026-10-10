import 'seats.dart' as seats;

/// An evening trip made ahead for booking (`trips/{date}_{busId}_fromCampus`).
class EveningTrip {
  const EveningTrip({
    required this.id,
    required this.busId,
    required this.routeId,
    required this.date,
    required this.status,
    required this.departsAt,
    required this.bookingOpensAt,
    required this.bookingClosesAt,
    required this.capacity,
    required this.passHolders,
    this.altHeld = 0,
    this.seatsBooked = 0,
    this.notRiding = 0,
    this.guestFare,
  });

  final String id;
  final String busId;
  final String routeId;

  /// YYYY-MM-DD, campus clock.
  final String date;

  /// `scheduled`, `running` or `ended`.
  final String status;
  final DateTime departsAt;
  final DateTime bookingOpensAt;
  final DateTime bookingClosesAt;
  final int capacity;
  final int passHolders;
  final int altHeld;
  final int seatsBooked;

  /// Pass holders who said they are not riding.
  final int notRiding;

  /// Rupees for one seat; null when the route offers no guest seats.
  final num? guestFare;

  /// Seats nobody has a claim on; see [seats.spareSeats].
  int get spareSeats => seats.spareSeats(
        capacity: capacity,
        passHolders: passHolders,
        notRiding: notRiding,
        altHeld: altHeld,
        seatsBooked: seatsBooked,
      );

  BookingWindow windowAt(DateTime now) {
    if (status == 'ended') return BookingWindow.closed;
    if (now.isBefore(bookingOpensAt)) return BookingWindow.notYet;
    return now.isBefore(bookingClosesAt) ? BookingWindow.open : BookingWindow.closed;
  }
}

enum BookingWindow { notYet, open, closed }

enum BookingStatus { pendingPayment, confirmed, used, cancelled, expired }

/// A `bookings/{tripId}_{uid}` document: one student's seat on one trip.
class Booking {
  const Booking({
    required this.id,
    required this.tripId,
    required this.routeId,
    required this.busId,
    required this.date,
    required this.departsAt,
    required this.stopId,
    required this.fare,
    required this.status,
    this.expiresAt,
    this.ticketToken,
    this.payment = const PaymentInfo(mode: PaymentMode.demo),
  });

  final String id;
  final String tripId;
  final String routeId;
  final String busId;
  final String date;
  final DateTime departsAt;

  /// Where the student gets off.
  final String stopId;
  final num fare;
  final BookingStatus status;

  /// An unpaid booking gives its seat back after this.
  final DateTime? expiresAt;

  /// Set once paid; makes the ticket QR.
  final String? ticketToken;
  final PaymentInfo payment;

  /// The QR the driver scans. Same format as ticketCode in
  /// functions/src/booking.ts: `WIMBT1.<bookingId>.<token>`.
  String? get ticketCode => ticketToken == null ? null : 'WIMBT1.$id.$ticketToken';
}

enum PaymentMode { free, demo, razorpay }

/// How the server wants the seat paid for.
class PaymentInfo {
  const PaymentInfo({required this.mode, this.keyId, this.orderId, this.amountPaise});

  final PaymentMode mode;

  /// Razorpay only: the public key and the order to pay.
  final String? keyId;
  final String? orderId;
  final int? amountPaise;

  static PaymentInfo fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    return PaymentInfo(
      mode: PaymentMode.values.where((m) => m.name == map['mode']).firstOrNull ?? PaymentMode.demo,
      keyId: map['keyId'] as String?,
      orderId: map['orderId'] as String?,
      amountPaise: (map['amountPaise'] as num?)?.toInt(),
    );
  }
}

/// What bookSeat in functions/src/bookings.ts answered.
enum BookResult {
  booked,
  alreadyBooked,
  full,
  notOpen,
  closed,
  passCovers,
  noGuestSeats,
  badStop,
  paymentsUnavailable,

  /// The phone could not reach the server.
  offline,
}

class BookOutcome {
  const BookOutcome(this.result, {this.bookingId, this.payment});

  final BookResult result;
  final String? bookingId;
  final PaymentInfo? payment;
}

enum PayResult { confirmed, expired, invalidPayment, notPending, offline }

/// Proof of payment for payBooking.
sealed class PaymentProof {
  const PaymentProof();
}

final class DemoPaymentProof extends PaymentProof {
  const DemoPaymentProof();
}

final class RazorpayPaymentProof extends PaymentProof {
  const RazorpayPaymentProof({required this.paymentId, required this.signature});

  final String paymentId;
  final String signature;
}
