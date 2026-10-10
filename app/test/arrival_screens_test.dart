import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';

import 'support/fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram');
const _trip = '2026-10-10_bus-01_toCampus';

/// The test clock reads 07:00:00. The test route runs Gandhipuram (07:00) →
/// Ukkadam (07:15, the student's stop) → campus (08:00).
final _now = DateTime(2026, 10, 10, 7);

LiveBus _busAt(double lat, double lng, {String status = 'running'}) => LiveBus(
      busId: 'bus-01',
      lat: lat,
      lng: lng,
      updatedAt: _now.subtract(const Duration(seconds: 4)),
      status: status,
      tripId: _trip,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _openHome(WidgetTester tester, {required LiveBus live, FakeStopTimesRepository? stopTimes}) async {
  final auth = FakeAuthRepository()
    ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam');
  await pumpApp(
    tester,
    auth,
    routes: FakeRouteRepository(auth, buses: [_bus]),
    live: FakeLiveRepository()..put(live),
    stopTimes: stopTimes,
  );
  await tester.tap(find.text("I'm a student"));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _studentEmail);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await _settle(tester);
}

void main() {
  testWidgets('shows minutes to the stop, from the timetable', (tester) async {
    // At the first stop: 15 scheduled minutes from Ukkadam.
    await _openHome(tester, live: _busAt(11.0183, 76.9672));
    expect(find.text('Arrives in 15 min'), findsOneWidget);
    expect(find.text('around 7:14 AM'), findsOneWidget);
  });

  testWidgets('says when the bus is at the stop', (tester) async {
    await _openHome(tester, live: _busAt(10.9890, 76.962));
    expect(find.text('The bus is at your stop now'), findsOneWidget);
  });

  testWidgets('says when the bus has passed, with the recorded time', (tester) async {
    final stopTimes = FakeStopTimesRepository()
      ..byTrip[_trip] = {'gandhipuram': DateTime(2026, 10, 10, 6, 58), 'ukkadam': DateTime(2026, 10, 10, 6, 59)};
    await _openHome(tester, live: _busAt(10.95, 76.94), stopTimes: stopTimes);
    expect(find.text('Passed your stop at 6:59 AM'), findsOneWidget);
  });

  testWidgets('an offline bus gets no estimate, only the schedule', (tester) async {
    await _openHome(tester, live: _busAt(11.0183, 76.9672, status: 'offline'));
    expect(find.textContaining('Arrives in'), findsNothing);
    expect(find.text('Bus due at 7:15 AM'), findsOneWidget);
  });

  testWidgets('the full route lists passed, current and coming stops', (tester) async {
    final stopTimes = FakeStopTimesRepository()..byTrip[_trip] = {'gandhipuram': DateTime(2026, 10, 10, 6, 58)};
    // Between Gandhipuram and Ukkadam.
    await _openHome(tester, live: _busAt(11.0035, 76.9646), stopTimes: stopTimes);

    await tester.ensureVisible(find.text('See all stops'));
    await tester.pump();
    await tester.tap(find.text('See all stops'));
    await _settle(tester);

    expect(find.text('Full route'), findsOneWidget);
    expect(find.text('Passed at 6:58 AM · Scheduled 7:00 AM'), findsOneWidget);
    expect(find.text('Bus is here'), findsOneWidget);
    expect(find.textContaining('Expected'), findsNWidgets(2)); // Ukkadam and the campus

    // Rows run in travel order, with the bus between the first two stops.
    final y = {
      for (final label in ['Gandhipuram Bus Stand', 'Bus is here', 'Ukkadam', 'Amrita Campus'])
        label: tester.getTopLeft(find.text(label)).dy,
    };
    expect(y['Gandhipuram Bus Stand']! < y['Bus is here']!, isTrue);
    expect(y['Bus is here']! < y['Ukkadam']!, isTrue);
    expect(y['Ukkadam']! < y['Amrita Campus']!, isTrue);
  });
}
