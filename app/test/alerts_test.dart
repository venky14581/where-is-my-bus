import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/alerts/domain/alert_prefs.dart';
import 'package:where_is_my_bus/features/alerts/domain/feed_item.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';
import 'package:where_is_my_bus/features/trip/data/trip_repository.dart';

import 'support/fakes.dart';
import 'support/trip_fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001');

/// The test clock reads 07:00.
final _now = DateTime(2026, 10, 10, 7);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(); // lay out at the new scroll position before tapping
  await tester.tap(finder);
  await _settle(tester);
}

Future<(FakeAuthRepository, FakeAlertsRepository, FakePushService)> _openStudent(
  WidgetTester tester, {
  List<FeedItem> feed = const [],
}) async {
  final auth = FakeAuthRepository()
    ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam');
  final alerts = FakeAlertsRepository(auth)..feed.addAll(feed);
  final push = FakePushService();
  await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), alerts: alerts, push: push);
  await _tap(tester, find.text("I'm a student"));
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _studentEmail);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  return (auth, alerts, push);
}

void main() {
  test('alert settings read defaults for anything missing', () {
    expect(AlertPrefs.fromMap(null).leadStops, 2);
    final prefs = AlertPrefs.fromMap({'delays': false, 'leadStops': 7, 'quietDays': [6, 7, 9]});
    expect(prefs.delays, isFalse);
    expect(prefs.approaching, isTrue);
    expect(prefs.leadStops, 2);
    expect(prefs.quietDays, {6, 7});
  });

  testWidgets('a verified student is registered for push, and removed on sign-out', (tester) async {
    final (_, _, push) = await _openStudent(tester);
    expect(push.registered, ['uid-$_studentEmail']);

    await _tap(tester, find.byIcon(Icons.more_vert));
    await _tap(tester, find.text('Sign out'));
    expect(push.unregistered, ['uid-$_studentEmail']);
  });

  testWidgets('the alerts list shows trip news and announcements, and clears the badge', (tester) async {
    await _openStudent(tester, feed: [
      TripAlert(id: '1', createdAt: _now.subtract(const Duration(minutes: 3)), kind: TripAlertKind.delay,
          busNumber: 'TN 37 AB 1201', minutes: 12),
      Announcement(id: '2', createdAt: _now.subtract(const Duration(hours: 5)), title: 'Holiday on Monday',
          body: 'No buses run on Monday.'),
    ]);
    expect(find.text('2'), findsOneWidget); // unread badge

    await _tap(tester, find.byTooltip('Alerts'));
    expect(find.text('TN 37 AB 1201 is running about 12 min behind schedule.'), findsOneWidget);
    expect(find.text('Holiday on Monday'), findsOneWidget);
    expect(find.textContaining('No buses run on Monday.'), findsOneWidget);
    expect(find.textContaining('3 min ago'), findsOneWidget);

    await _tap(tester, find.byType(BackButton));
    expect(find.text('2'), findsNothing);
  });

  testWidgets('notification settings save as soon as they change', (tester) async {
    final (_, alerts, _) = await _openStudent(tester);
    await _tap(tester, find.byTooltip('Alerts'));
    expect(find.textContaining('No alerts right now'), findsOneWidget);
    await _tap(tester, find.byTooltip('Notifications'));

    await _tap(tester, find.text('3 stops away'));
    expect(alerts.saved.last.leadStops, 3);

    await _tap(tester, find.text('Delays and breakdowns'));
    expect(alerts.saved.last.delays, isFalse);

    await _tap(tester, find.text('Sun'));
    expect(alerts.saved.last.quietDays, {7});
    expect(alerts.saved.last.leadStops, 3); // earlier choices kept
  });

  testWidgets('the driver reports running late in one tap, and a breakdown after confirming', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final trips = FakeTripRepository();
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), trips: trips);
    await _tap(tester, find.text("I'm a driver"));
    await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _tap(tester, find.text('Start Trip'));

    await _tap(tester, find.text('Running late'));
    expect(trips.reports, [TripIssue.late]);
    expect(find.text('Riders have been told.'), findsOneWidget);

    await _tap(tester, find.text('Breakdown'));
    await _tap(tester, find.text('Cancel'));
    expect(trips.reports, [TripIssue.late]);

    await _tap(tester, find.text('Breakdown'));
    await _tap(tester, find.text('Report'));
    expect(trips.reports, [TripIssue.late, TripIssue.breakdown]);
  });
}
