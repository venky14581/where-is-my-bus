import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_bootstrap.dart';
import '../data/booking_repository.dart';
import '../data/payment_gateway.dart';
import '../domain/booking.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FirebaseBookingRepository(FirebaseFirestore.instance, FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final paymentGatewayProvider = Provider<PaymentGateway>((ref) => AppPaymentGateway());

/// Keyed by the dates joined with commas, so the family key compares by value.
final eveningTripsProvider = StreamProvider.autoDispose.family<List<EveningTrip>, String>(
  (ref, dates) => ref.watch(bookingRepositoryProvider).watchEveningTrips(dates.split(',')),
);

final myBookingsProvider = StreamProvider.autoDispose.family<List<Booking>, String>(
  (ref, uid) => ref.watch(bookingRepositoryProvider).watchMyBookings(uid),
);
