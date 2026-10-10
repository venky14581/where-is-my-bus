import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/live/domain/live_bus.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';

import 'support/fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _bus1 = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram');
const _bus3 = Bus(id: 'bus-03', number: 'TN 37 AB 1203', capacity: 45, routeId: 'pkd-town');

/// The test clock reads 07:00:00.
final _now = DateTime(2026, 10, 10, 7);

LiveBus _live(String busId, {Duration age = const Duration(seconds: 4), String status = 'running'}) => LiveBus(
      busId: busId,
      lat: 10.99,
      lng: 76.96,
      updatedAt: _now.subtract(age),
      status: status,
    );

Future<void> _openHome(WidgetTester tester, FakeLiveRepository live, {List<Bus> buses = const [_bus1, _bus3]}) async {
  final auth = FakeAuthRepository()
    ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam');
  await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: buses), live: live);
  await tester.tap(find.text("I'm a student"));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _studentEmail);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await _settle(tester);
}

/// Lets navigation and the marker animation finish. The ticking status
/// line keeps scheduling frames, so pumpAndSettle would wait forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('LiveBus.stateAt', () {
    test('live, then stale after 30 s without an update', () {
      expect(_live('b', age: const Duration(seconds: 29)).stateAt(_now), BusLiveState.live);
      expect(_live('b', age: const Duration(seconds: 31)).stateAt(_now), BusLiveState.stale);
    });

    test('offline when the server says so, not running when ended or hours old', () {
      expect(_live('b', status: 'offline').stateAt(_now), BusLiveState.offline);
      expect(_live('b', status: 'ended').stateAt(_now), BusLiveState.notRunning);
      expect(_live('b', age: const Duration(hours: 3)).stateAt(_now), BusLiveState.notRunning);
      expect(_live('b', age: const Duration(hours: 3), status: 'offline').stateAt(_now), BusLiveState.notRunning);
    });

    test('malformed data is treated as no bus', () {
      expect(LiveBus.tryFromMap('b', {'lat': 'x', 'lng': 1, 'updatedAt': 1, 'status': 'running'}), isNull);
      expect(LiveBus.tryFromMap('b', null), isNull);
      expect(
        LiveBus.tryFromMap('b', {'lat': 10.9, 'lng': 76.9, 'updatedAt': 1791640000000, 'status': 'running'})!.lat,
        10.9,
      );
    });
  });

  testWidgets('the student home opens on a map of their bus, with how fresh it is', (tester) async {
    final live = FakeLiveRepository()..put(_live('bus-01'));
    await _openHome(tester, live);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Live · updated 4 s ago'), findsOneWidget);
    expect(find.text('Ukkadam'), findsOneWidget);
    expect(find.text('Bus due at 7:15 AM'), findsOneWidget);
    expect(find.byTooltip('TN 37 AB 1201'), findsOneWidget);
  });

  testWidgets('a quiet bus is shown as weak signal, then offline, then not running', (tester) async {
    final live = FakeLiveRepository()..put(_live('bus-01', age: const Duration(minutes: 2)));
    await _openHome(tester, live);
    expect(find.text('Weak signal · last position 2 min ago'), findsOneWidget);

    live.put(_live('bus-01', age: const Duration(minutes: 10), status: 'offline'));
    await _settle(tester);
    expect(find.text('Offline · last seen at 6:50 AM'), findsOneWidget);
    expect(find.byTooltip('TN 37 AB 1201'), findsOneWidget); // still drawn, in grey

    live.put(_live('bus-01', status: 'ended'));
    await _settle(tester);
    expect(find.text("The bus isn't running right now."), findsOneWidget);
    expect(find.byTooltip('TN 37 AB 1201'), findsNothing);
  });

  testWidgets('a route with no bus says so', (tester) async {
    await _openHome(tester, FakeLiveRepository(), buses: const [_bus3]);
    expect(find.text('No bus is assigned to this route yet.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('all buses lists only the running ones', (tester) async {
    final live = FakeLiveRepository()
      ..put(_live('bus-01'))
      ..put(_live('bus-03', age: const Duration(minutes: 5), status: 'offline'))
      ..put(_live('bus-02', status: 'ended'));
    await _openHome(tester, live);

    await tester.tap(find.byTooltip('All buses'));
    await _settle(tester);

    expect(find.text('All buses'), findsOneWidget);
    expect(find.text('TN 37 AB 1201 · Gandhipuram – Campus'), findsWidgets);
    expect(find.text('TN 37 AB 1203 · Palakkad – Campus'), findsWidgets);
    expect(find.text('Offline · last seen at 6:55 AM'), findsOneWidget);
    expect(find.textContaining('bus-02'), findsNothing);
  });
}
