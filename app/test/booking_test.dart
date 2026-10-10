import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:where_is_my_bus/features/booking/domain/booking.dart';
import 'package:where_is_my_bus/features/pass/data/pass_repository.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';

import 'support/fakes.dart';

const _email = 'cb.en.u4cse21001@cb.students.amrita.edu';

const _rsPuram = BusRoute(id: 'cbe-rs-puram', name: 'R.S. Puram – Campus', city: 'Coimbatore', stops: [
  RouteStop(id: 'rs-puram', name: 'R.S. Puram', lat: 11.009, lng: 76.95, scheduledTime: '07:05'),
  RouteStop(id: 'selvapuram', name: 'Selvapuram', lat: 10.99, lng: 76.94, scheduledTime: '07:15'),
  testCampus,
]);
const _buses = [
  Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001'),
  Bus(id: 'bus-02', number: 'TN 37 AB 1202', capacity: 50, routeId: 'cbe-rs-puram'),
  Bus(id: 'bus-03', number: 'TN 37 AB 1203', capacity: 45, routeId: 'pkd-town'),
];

/// Test clock: 07:00 on 10 Oct 2026.
EveningTrip _trip(String busId, String routeId, String date, {num? fare = 40, int passHolders = 44, int booked = 0}) {
  final day = DateTime.parse(date);
  final before = day.subtract(const Duration(days: 1));
  return EveningTrip(
    id: '${date}_${busId}_fromCampus',
    busId: busId,
    routeId: routeId,
    date: date,
    status: 'scheduled',
    departsAt: DateTime(day.year, day.month, day.day, 16, 30),
    bookingOpensAt: DateTime(before.year, before.month, before.day, 18),
    bookingClosesAt: DateTime(day.year, day.month, day.day, 16),
    capacity: 50,
    passHolders: passHolders,
    seatsBooked: booked,
    guestFare: fare,
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _signIn(WidgetTester tester) async {
  await _tap(tester, find.text("I'm a student"));
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
}

void main() {
  group('evening trips', () {
    final trip = _trip('bus-02', 'cbe-rs-puram', '2026-10-10');

    test('booking opens the evening before and closes before departure', () {
      expect(trip.windowAt(DateTime(2026, 10, 9, 17, 59)), BookingWindow.notYet);
      expect(trip.windowAt(DateTime(2026, 10, 9, 18)), BookingWindow.open);
      expect(trip.windowAt(DateTime(2026, 10, 10, 16)), BookingWindow.closed);
    });

    test("spare seats leave the route's pass holders theirs", () {
      expect(trip.spareSeats, 6);
      expect(_trip('bus-02', 'cbe-rs-puram', '2026-10-10', passHolders: 48, booked: 5).spareSeats, 0);
    });

    test('a ticket QR is the code the server checks', () {
      // The example in functions/src/booking.test.ts.
      final booking = Booking(
        id: '2026-10-12_bus-01_fromCampus_student-demo',
        tripId: '2026-10-12_bus-01_fromCampus',
        routeId: 'r',
        busId: 'b',
        date: '2026-10-12',
        departsAt: DateTime(2026, 10, 12, 16, 30),
        stopId: 's',
        fare: 40,
        status: BookingStatus.confirmed,
        ticketToken: 'abc_DEF-123',
      );
      expect(booking.ticketCode, 'WIMBT1.2026-10-12_bus-01_fromCampus_student-demo.abc_DEF-123');
    });
  });

  group('evening seats screen', () {
    Future<(FakeBookingRepository, FakePaymentGateway)> open(WidgetTester tester) async {
      final auth = FakeAuthRepository()
        ..addStudent(_email, 'bus-pass-123',
            routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: true, passValidUntil: '2026-12-31');
      final bookings = FakeBookingRepository()
        ..trips.addAll([
          _trip('bus-02', 'cbe-rs-puram', '2026-10-10'),
          _trip('bus-01', 'cbe-gandhipuram', '2026-10-11'),
          _trip('bus-03', 'pkd-town', '2026-10-11', fare: 60),
        ]);
      final payments = FakePaymentGateway();
      await pumpApp(
        tester,
        auth,
        routes: FakeRouteRepository(auth, routes: [...testRoutes, _rsPuram], buses: _buses),
        bookings: bookings,
        payments: payments,
      );
      await _signIn(tester);
      await _tap(tester, find.text('Evening seats'));
      return (bookings, payments);
    }

    testWidgets('lists evening buses with fare, seats and booking times', (tester) async {
      await open(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('R.S. Puram – Campus'), findsOneWidget);
      expect(find.text('₹40 · 6 seats left'), findsNWidgets(2));
      expect(find.text('Book until 4:00 PM'), findsOneWidget);
      // Tomorrow's buses open at 6 PM today.
      await tester.scrollUntilVisible(find.text('Booking opens at 6:00 PM'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Booking opens at 6:00 PM'), findsNWidgets(1));
      // The student's own route: their pass covers it.
      expect(find.text('Your bus pass covers this bus.'), findsOneWidget);
    });

    testWidgets('books a seat, pays and gets a one-scan ticket', (tester) async {
      final (bookings, payments) = await open(tester);
      await _tap(tester, find.text('Book a seat'));
      expect(find.text('Where do you get off?'), findsOneWidget);
      // Evening buses run outwards from campus: Selvapuram comes first.
      final selvapuram = tester.getTopLeft(find.text('Selvapuram')).dy;
      final rsPuram = tester.getTopLeft(find.text('R.S. Puram')).dy;
      expect(selvapuram, lessThan(rsPuram));
      await _tap(tester, find.text('Selvapuram'));
      await _tap(tester, find.text('Book for ₹40'));

      expect(bookings.requests.single, (tripId: '2026-10-10_bus-02_fromCampus', stopId: 'selvapuram'));
      expect(payments.charged, [40]);
      await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
      await _settle(tester);
      expect(find.text('Your tickets'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Get off at Selvapuram'), findsOneWidget);
      expect(find.text('Show this to the driver. It works for one scan.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('You have a seat on this bus'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('You have a seat on this bus'), findsOneWidget);
    });

    testWidgets('backing out of payment gives the seat straight back', (tester) async {
      final (bookings, payments) = await open(tester);
      payments.backOut = true;
      await _tap(tester, find.text('Book a seat'));
      await _tap(tester, find.text('Selvapuram'));
      await _tap(tester, find.text('Book for ₹40'));
      expect(bookings.cancelled, ['2026-10-10_bus-02_fromCampus_me']);
      expect(find.text('Payment cancelled, so the seat was released.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('a full bus says so', (tester) async {
      final (bookings, _) = await open(tester);
      bookings.nextResult = BookResult.full;
      await _tap(tester, find.text('Book a seat'));
      await _tap(tester, find.text('Selvapuram'));
      await _tap(tester, find.text('Book for ₹40'));
      expect(find.text('Sorry, no seats are left.'), findsOneWidget);
    });
  });

  testWidgets('a hosteller skips the daily route and goes straight to evening seats', (tester) async {
    final auth = FakeAuthRepository()..addStudent(_email, 'bus-pass-123');
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: _buses));
    await _signIn(tester);
    await _tap(tester, find.text("I don't take a college bus every day"));
    expect(find.textContaining('You have no daily college bus'), findsOneWidget);
    await _tap(tester, find.text('Evening seats'));
    expect(find.text('No evening buses to book yet. Booking opens the evening before.'), findsOneWidget);
  });

  testWidgets('the driver sees ticket verdicts', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final passes = FakePassRepository()
      ..decide = (code) => switch (code) {
            'used' => const ScanOutcome(ScanResult.ticketUsed),
            'other-bus' => const ScanOutcome(ScanResult.wrongTrip, name: 'Ravi'),
            _ => const ScanOutcome(ScanResult.notPaid, name: 'Bala'),
          };
    final scanner = FakeScanner();
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: _buses), passes: passes, scanner: scanner);
    await _tap(tester, find.text("I'm a driver"));
    await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _tap(tester, find.text('Start Trip'));
    await _tap(tester, find.text('Scan pass'));

    Future<void> scan(String code) async {
      scanner.emit(code);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await scan('used');
    expect(find.text('This ticket has already been used.'), findsOneWidget);
    await scan('other-bus');
    expect(find.text("Ravi's ticket is for another bus."), findsOneWidget);
    await scan('unpaid');
    expect(find.text("Bala's ticket is not paid."), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

