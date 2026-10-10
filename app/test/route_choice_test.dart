import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';

import 'support/fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _signInStudent(WidgetTester tester) async {
  await _tap(tester, find.text("I'm a student"));
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _studentEmail);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
}

void main() {
  testWidgets('a new student picks city, route and stop, then sees it on the home screen', (tester) async {
    final auth = FakeAuthRepository()..addStudent(_studentEmail, 'bus-pass-123');
    const bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram');
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [bus]));

    await _signInStudent(tester);
    expect(find.text('Where do you travel from?'), findsOneWidget);
    expect(find.text('Palakkad'), findsOneWidget);

    await _tap(tester, find.text('Coimbatore'));
    expect(find.text('Choose your route'), findsOneWidget);
    expect(find.text('Palakkad – Campus'), findsNothing);

    await _tap(tester, find.text('Gandhipuram – Campus'));
    expect(find.text('Choose your stop'), findsOneWidget);
    // The campus is the destination, not a pickup stop.
    expect(find.text('Amrita Campus'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);

    await _tap(tester, find.text('Ukkadam'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Save'));

    expect(find.text('Your stop'), findsOneWidget);
    expect(find.text('Ukkadam'), findsOneWidget);
    expect(find.text('Gandhipuram – Campus'), findsOneWidget);
    expect(find.text('Bus TN 37 AB 1201'), findsOneWidget);
    expect(find.text('Bus due at 7:15 AM'), findsOneWidget);
  });

  testWidgets('back steps through the picker one level at a time', (tester) async {
    final auth = FakeAuthRepository()..addStudent(_studentEmail, 'bus-pass-123');
    await pumpApp(tester, auth);

    await _signInStudent(tester);
    await _tap(tester, find.text('Palakkad'));
    await _tap(tester, find.text('Palakkad – Campus'));
    expect(find.text('Choose your stop'), findsOneWidget);

    await _tap(tester, find.byType(BackButton));
    expect(find.text('Choose your route'), findsOneWidget);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('Where do you travel from?'), findsOneWidget);
    // First-time setup: no way back past the first step.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a student can change their stop later', (tester) async {
    final auth = FakeAuthRepository()
      ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam');
    await pumpApp(tester, auth);

    await _signInStudent(tester);
    await _tap(tester, find.text('Change'));
    await _tap(tester, find.text('Coimbatore'));
    await _tap(tester, find.text('Gandhipuram – Campus'));
    await _tap(tester, find.text('Gandhipuram Bus Stand'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Save'));

    expect(find.text('Gandhipuram Bus Stand'), findsOneWidget);
    expect(find.text('Bus due at 7:00 AM'), findsOneWidget);
  });

  testWidgets('a removed route asks the student to choose again', (tester) async {
    final auth = FakeAuthRepository()
      ..addStudent(_studentEmail, 'bus-pass-123', routeId: 'old-route', stopId: 'old-stop');
    await pumpApp(tester, auth);

    await _signInStudent(tester);

    expect(find.text('Your route or stop is no longer running. Choose another.'), findsOneWidget);
    await _tap(tester, find.text('Choose route'));
    expect(find.text('Where do you travel from?'), findsOneWidget);
  });

  testWidgets('the driver home shows the assigned bus and route', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    const bus = Bus(
      id: 'bus-01',
      number: 'TN 37 AB 1201',
      capacity: 50,
      routeId: 'cbe-gandhipuram',
      driverId: 'uid-DRV001',
    );
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [bus]));

    await _tap(tester, find.text("I'm a driver"));
    await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

    expect(find.text('TN 37 AB 1201'), findsOneWidget);
    expect(find.text('Gandhipuram – Campus'), findsOneWidget);
    expect(find.text('2 stops · First pickup 7:00 AM'), findsOneWidget);
    expect(find.text("Trip tracking isn't switched on yet."), findsOneWidget);
  });
}
