import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/safety/data/safety_repository.dart';

import 'support/fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// The student home's list below the map builds only what is on screen.
Finder get _homeList => find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 150, scrollable: _homeList);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  group('driver', () {
    Future<void> openRunningTrip(WidgetTester tester, FakeSafetyRepository safety) async {
      final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
      await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), safety: safety);
      await _tap(tester, find.text("I'm a driver"));
      await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
      await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
      await _tap(tester, find.text('Start Trip'));
    }

    testWidgets('SOS asks first, then tells the office', (tester) async {
      final safety = FakeSafetyRepository();
      await openRunningTrip(tester, safety);

      await _tap(tester, find.text('SOS'));
      expect(find.text('Send SOS?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(safety.sosCount, 0);

      await _tap(tester, find.text('SOS'));
      await _tap(tester, find.text('Send SOS'));
      expect(safety.sosCount, 1);
      expect(find.text('SOS sent. The transport office knows where the bus is.'), findsOneWidget);
    });

    testWidgets('without a connection the driver is told it did not go', (tester) async {
      final safety = FakeSafetyRepository()..sos = SosResult.offline;
      await openRunningTrip(tester, safety);
      await _tap(tester, find.text('SOS'));
      await _tap(tester, find.text('Send SOS'));
      expect(find.text('No internet connection'), findsOneWidget);
    });
  });

  group('student', () {
    final now = DateTime(2026, 10, 10, 7);

    Future<void> openHome(WidgetTester tester, {required FakeSafetyRepository safety, required bool running}) async {
      final auth = FakeAuthRepository()
        ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam');
      final live = FakeLiveRepository();
      if (running) {
        live.put(LiveBus(
          busId: 'bus-01', lat: 11.0183, lng: 76.9672, status: 'running',
          tripId: '2026-10-10_bus-01_toCampus', updatedAt: now.subtract(const Duration(seconds: 4)),
        ));
      }
      await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), live: live, safety: safety);
      await _tap(tester, find.text("I'm a student"));
      await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _studentEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    }

    testWidgets('shares the running trip as a link a parent can open', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      final safety = FakeSafetyRepository();
      await openHome(tester, safety: safety, running: true);
      await _scrollTo(tester, find.text('Share my trip'));
      await _tap(tester, find.text('Share my trip'));
      expect(safety.shareCount, 1);
      expect(find.text('http://localhost:5173/#/share/tok123'), findsOneWidget);
      expect(find.textContaining('It shows the bus, never you.'), findsOneWidget);
      await _tap(tester, find.text('Copy link'));
      expect(copied, 'http://localhost:5173/#/share/tok123');
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('SOS from a student on the bus', (tester) async {
      final safety = FakeSafetyRepository();
      await openHome(tester, safety: safety, running: true);
      await _scrollTo(tester, find.text('SOS'));
      await _tap(tester, find.text('SOS'));
      await _tap(tester, find.text('Send SOS'));
      expect(safety.sosCount, 1);
    });

    testWidgets('no share or SOS while the bus is not running', (tester) async {
      await openHome(tester, safety: FakeSafetyRepository(), running: false);
      // To the end of the list, where the buttons would be.
      await _scrollTo(tester, find.text('See all stops'));
      expect(find.text('Evening seats'), findsOneWidget);
      expect(find.text('Share my trip'), findsNothing);
      expect(find.text('SOS'), findsNothing);
    });
  });
}
