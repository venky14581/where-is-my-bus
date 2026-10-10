import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/booking/domain/booking.dart';
import 'package:where_is_my_bus/features/booking/domain/seats.dart';
import 'package:where_is_my_bus/features/eta/domain/arrival.dart';
import 'package:where_is_my_bus/features/eta/domain/learned_times.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/smart/data/smart_repository.dart';
import 'package:where_is_my_bus/features/trip/domain/trip_plan.dart';

import 'support/fakes.dart';

// The same example as functions/src/learned.test.ts.
final _learned = LearnedTimes.fromMap({
  'slotMinutes': 30,
  'toCampus': {
    '1': {'07:00': [600, 700, 800], '07:30': [660, 770, 880]},
    '2': {'07:00': [500, 600, 700]},
  },
  'delayByWeekday': {'1': {'minutes': 6, 'trips': 8}},
});
final _monday0740 = DateTime.parse('2026-10-12T07:40:00+05:30');

void main() {
  group('learned times', () {
    test('campus clock and half-hour slots', () {
      expect(campusClock(_monday0740), (weekday: 1, minute: 460));
      expect(campusClock(DateTime.parse('2026-10-11T23:00:00+05:30')).weekday, 7);
      expect(slotKey(7 * 60 + 29), '07:00');
      expect(slotKey(7 * 60 + 30), '07:30');
      expect(slotKey(0), '00:00');
    });

    test('the nearest slot on the same weekday, within an hour', () {
      const to = TripDirection.toCampus;
      expect(learnedSegments(_learned, to, _monday0740, 4), [660, 770, 880]);
      expect(learnedSegments(_learned, to, DateTime.parse('2026-10-12T06:10:00+05:30'), 4), [600, 700, 800]);
      expect(learnedSegments(_learned, to, DateTime.parse('2026-10-12T05:30:00+05:30'), 4), isNull);
      expect(learnedSegments(_learned, to, DateTime.parse('2026-10-14T07:00:00+05:30'), 4), isNull);
      expect(learnedSegments(_learned, TripDirection.fromCampus, _monday0740, 4), isNull);
      expect(learnedSegments(_learned, to, _monday0740, 5), isNull);
      expect(learnedSegments(null, to, _monday0740, 4), isNull);
      expect(_learned.delayByWeekday[1]?.minutes, 6);
    });

    test("today's slowness only adds time, within limits, once measured", () {
      expect(trafficFactor(null), 1);
      expect(trafficFactor(const Conditions(ratioSum: 2.6, count: 2)), 1);
      expect(trafficFactor(const Conditions(ratioSum: 3.6, count: 3)), closeTo(1.2, 1e-9));
      expect(trafficFactor(const Conditions(ratioSum: 2.4, count: 3)), 1);
      expect(trafficFactor(const Conditions(ratioSum: 9, count: 3)), 1.5);
    });

    test('leave the walk plus two minutes before the bus', () {
      expect(leaveAt(DateTime.parse('2026-10-12T07:40:00+05:30'), 8), DateTime.parse('2026-10-12T07:30:00+05:30'));
    });

    test('an estimate follows learned times, stretched by the day', () {
      const route = BusRoute(id: 'line', name: 'Line', city: 'C', stops: [
        RouteStop(id: 'a', name: 'A', lat: 11.00, lng: 76.96, scheduledTime: '07:00'),
        RouteStop(id: 'b', name: 'B', lat: 10.99, lng: 76.96, scheduledTime: '07:10'),
        RouteStop(id: 'campus', name: 'Campus', lat: 10.98, lng: 76.96, scheduledTime: '07:20'),
      ]);
      final timeline = RouteTimeline.of(route);
      Duration eta(TravelModel? travel) =>
          (timeline.arrivalAt(stopId: 'b', busLat: 10.995, busLng: 76.96, direction: TripDirection.toCampus, travel: travel)
                  as Approaching)
              .eta;
      expect(eta(null).inSeconds, closeTo(300, 5)); // half of the 10 timetable minutes
      expect(eta(const TravelModel(segments: [1200, 600])).inSeconds, closeTo(600, 5));
      expect(eta(const TravelModel(segments: [1200, 600], factor: 1.2)).inSeconds, closeTo(720, 6));
      expect(eta(const TravelModel(segments: [1200])).inSeconds, closeTo(300, 5)); // does not fit: timetable
    });
  });

  group('seats', () {
    test("pass holders not riding free their seats, never more than they hold", () {
      // The same examples as functions/src/booking.test.ts.
      expect(spareSeats(capacity: 50, passHolders: 48, notRiding: 3, seatsBooked: 4), 1);
      expect(spareSeats(capacity: 50, passHolders: 2, notRiding: 5), 50);
      expect(spareSeats(capacity: 50, passHolders: 55), 0);
    });

    test('crowding: seats, a few, or standing', () {
      expect(crowdLevel(capacity: 50, passHolders: 30), CrowdLevel.seatsAvailable);
      expect(crowdLevel(capacity: 50, passHolders: 45), CrowdLevel.fewSeats);
      expect(crowdLevel(capacity: 50, passHolders: 52, notRiding: 4), CrowdLevel.fewSeats);
      expect(crowdLevel(capacity: 50, passHolders: 50), CrowdLevel.standingOnly);
      expect(crowdLevel(capacity: 20, passHolders: 17), CrowdLevel.fewSeats);
    });
  });

  group('student home', () {
    const email = 'cb.en.u4cse21001@cb.students.amrita.edu';
    const bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram');
    const trip = '2026-10-10_bus-01_toCampus';
    // The test clock reads 07:00 on 10 Oct 2026; the bus is at Gandhipuram,
    // 15 timetable minutes from Ukkadam, the student's stop.
    final now = DateTime(2026, 10, 10, 7);
    final live = LiveBus(
      busId: 'bus-01', lat: 11.0183, lng: 76.9672, status: 'running', tripId: trip,
      updatedAt: now.subtract(const Duration(seconds: 4)),
    );

    /// Learned times for every weekday and slot, so the result does not
    /// depend on the time zone the tests run in.
    LearnedTimes everywhere(List<int> segments, {int lateMinutes = 6}) => LearnedTimes(
          toCampus: {
            for (var day = 1; day <= 7; day++)
              day: {for (var m = 0; m < 24 * 60; m += 30) slotKey(m): segments},
          },
          delayByWeekday: {for (var day = 1; day <= 7; day++) day: DelayPattern(minutes: lateMinutes, trips: 8)},
        );

    Future<void> open(WidgetTester tester, {required FakeSmartRepository smart, int? walkMinutes}) async {
      final auth = FakeAuthRepository()
        ..addStudent(email, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam', walkMinutes: walkMinutes);
      await pumpApp(
        tester,
        auth,
        routes: FakeRouteRepository(auth, buses: [bus]),
        live: FakeLiveRepository()..put(live),
        smart: smart,
      );
      await tester.tap(find.text("I'm a student"));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'College email'), email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('learned times replace the timetable, and a slow morning stretches them', (tester) async {
      final smart = FakeSmartRepository()..learned['cbe-gandhipuram'] = everywhere([1800, 2700]);
      await open(tester, smart: smart);
      expect(find.text('Arrives in 30 min'), findsOneWidget);

      smart
        ..conditions['2026-10-10'] = const Conditions(ratioSum: 3.6, count: 3)
        ..emit();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Arrives in 36 min'), findsOneWidget);
    });

    testWidgets('a student who gave their walk is told when to leave', (tester) async {
      await open(tester, smart: FakeSmartRepository(), walkMinutes: 10);
      // Bus due 7:14:56 by the timetable; 10 min walk and 2 spare.
      expect(find.text('Leave home by 7:02 AM'), findsOneWidget);
    });

    testWidgets('a walk longer than the time left says leave now', (tester) async {
      await open(tester, smart: FakeSmartRepository(), walkMinutes: 20);
      expect(find.text('Leave now to catch it'), findsOneWidget);
    });

    testWidgets('no walk given, no leave-home line', (tester) async {
      await open(tester, smart: FakeSmartRepository());
      expect(find.textContaining('Leave'), findsNothing);
    });

    testWidgets("today's usual delay and how full the bus is", (tester) async {
      final smart = FakeSmartRepository()
        ..learned['cbe-gandhipuram'] = everywhere([900, 2700])
        ..seats[trip] = const TripSeats(passHolders: 46, altHeld: 1);
      await open(tester, smart: smart);
      expect(find.textContaining('Usually about 6 min late on'), findsOneWidget);
      expect(find.text('Few seats left'), findsOneWidget);
    });
  });

  group('evening seats', () {
    testWidgets('a pass holder gives up their evening seat, until booking closes', (tester) async {
      const email = 'cb.en.u4cse21001@cb.students.amrita.edu';
      final auth = FakeAuthRepository()
        ..addStudent(email, 'bus-pass-123',
            routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: true, passValidUntil: '2026-12-31');
      // Test clock 07:00 on 10 Oct: today's bus is open, tomorrow's not yet.
      EveningTrip trip(String date, DateTime opens) => EveningTrip(
            id: '${date}_bus-01_fromCampus',
            busId: 'bus-01',
            routeId: 'cbe-gandhipuram',
            date: date,
            status: 'scheduled',
            departsAt: DateTime.parse('${date}T16:30:00'),
            bookingOpensAt: opens,
            bookingClosesAt: DateTime.parse('${date}T16:00:00'),
            capacity: 50,
            passHolders: 44,
            guestFare: 40,
          );
      final bookings = FakeBookingRepository()
        ..trips.add(trip('2026-10-10', DateTime(2026, 10, 9, 18)));
      final smart = FakeSmartRepository();
      await pumpApp(tester, auth, routes: FakeRouteRepository(auth), bookings: bookings, smart: smart);
      await tester.tap(find.text("I'm a student"));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'College email'), email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.ensureVisible(find.text('Evening seats'));
      await tester.tap(find.text('Evening seats'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.text('Your bus pass covers this bus.'), findsOneWidget);
      expect(find.text('Another student can book your seat. You can change this until 4:00 PM.'), findsOneWidget);
      await tester.tap(find.text('Not riding this evening'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(smart.requests.single, (tripId: '2026-10-10_bus-01_fromCampus', notRiding: true));
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

      // Taking it back after the seat was sold.
      smart.nextNotRiding = NotRidingResult.seatTaken;
      await tester.tap(find.text('Not riding this evening'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your seat has been booked by someone else, so it cannot be taken back.'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    });
  });
}
