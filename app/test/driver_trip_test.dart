import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/data/location_source.dart';
import 'package:where_is_my_bus/features/trip/domain/fix.dart';

import 'support/fakes.dart';
import 'support/trip_fakes.dart';

const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001');

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _signInDriver(WidgetTester tester) async {
  await _tap(tester, find.text("I'm a driver"));
  await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
  await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the driver starts the trip, sees it sending, and ends it after confirming', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final trips = FakeTripRepository();
    final location = FakeLocationSource();
    await pumpApp(tester, auth,
        routes: FakeRouteRepository(auth, buses: [_bus]), trips: trips, location: location);
    await _signInDriver(tester);

    expect(find.text('Morning trip to campus'), findsOneWidget);
    await _tap(tester, find.text('Start Trip'));
    trips.setOnline(true);
    await tester.pump();

    expect(find.text('End Trip'), findsOneWidget);
    expect(find.text('Sharing bus location'), findsOneWidget);
    expect(find.text('Waiting for GPS…'), findsOneWidget);
    expect(find.text('Next stop: Gandhipuram Bus Stand'), findsOneWidget);
    // No signing out mid-trip.
    expect(find.byIcon(Icons.more_vert), findsNothing);

    location.emit(Fix(lat: 11.0183, lng: 76.9672, time: DateTime(2026, 10, 10, 7), accuracyM: 5));
    await tester.pump();
    expect(trips.published, hasLength(1));
    expect(find.textContaining('s ago'), findsOneWidget);
    expect(find.text('Next stop: Ukkadam'), findsOneWidget);
    expect(trips.stopArrivals, ['gandhipuram']);

    // Cancelling the confirmation keeps the trip running.
    await _tap(tester, find.text('End Trip'));
    await _tap(tester, find.text('Cancel'));
    expect(trips.ended, isEmpty);

    await _tap(tester, find.text('End Trip'));
    await _tap(tester, find.widgetWithText(FilledButton, 'End Trip').last);
    await tester.pumpAndSettle();
    expect(trips.ended, ['2026-10-10_bus-01_toCampus']);
    expect(find.text('Start Trip'), findsOneWidget);
  });

  testWidgets('with location off, the driver is told and offered settings', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final location = FakeLocationSource(access: LocationAccess.serviceDisabled);
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), location: location);
    await _signInDriver(tester);

    await _tap(tester, find.text('Start Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Location is off. Turn it on to start the trip.'), findsOneWidget);

    await _tap(tester, find.text('Open settings'));
    expect(location.settingsOpened, [LocationAccess.serviceDisabled]);
  });

  testWidgets('a fake GPS reading shows a warning and is not sent', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final trips = FakeTripRepository();
    final location = FakeLocationSource();
    await pumpApp(tester, auth,
        routes: FakeRouteRepository(auth, buses: [_bus]), trips: trips, location: location);
    await _signInDriver(tester);
    await _tap(tester, find.text('Start Trip'));
    trips.setOnline(true);

    location.emit(Fix(lat: 11.0, lng: 76.96, time: DateTime(2026, 10, 10, 7), isMocked: true));
    await tester.pump();

    expect(find.textContaining('Fake GPS detected'), findsOneWidget);
    expect(trips.published, isEmpty);
  });
}
