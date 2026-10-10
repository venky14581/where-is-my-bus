import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out, the app opens on the role choice', (tester) async {
    await pumpApp(tester, FakeAuthRepository());

    expect(find.text("I'm a student"), findsOneWidget);
    expect(find.text("I'm a driver"), findsOneWidget);
  });

  group('driver', () {
    testWidgets('signs in with ID and PIN, picks Tamil, lands on the driver home', (tester) async {
      final auth = FakeAuthRepository()..addDriver('DRV001', '482913');
      final settings = InMemorySettingsStore();
      await pumpApp(tester, auth, settings: settings);

      await _tap(tester, find.text("I'm a driver"));
      await _enter(tester, 'Driver ID', 'drv001');
      await _enter(tester, 'PIN', '482913');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

      // First login: language choice, shown in both languages.
      expect(find.text('Choose your language'), findsOneWidget);
      await _tap(tester, find.text('தமிழ்'));

      expect(find.text('பயணத்தைத் தொடங்கு'), findsOneWidget); // Start Trip
      expect(find.text('வணக்கம், Murugan'), findsOneWidget);
      expect(settings.values['locale'], 'ta');
    });

    testWidgets('a wrong PIN shows an error and stays on the sign-in screen', (tester) async {
      final auth = FakeAuthRepository()..addDriver('DRV001', '482913');
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a driver"));
      await _enter(tester, 'Driver ID', 'DRV001');
      await _enter(tester, 'PIN', '111111');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

      expect(find.text('Driver ID or PIN is wrong'), findsOneWidget);
      expect(find.text('Driver sign in'), findsOneWidget);
    });

    testWidgets('a short PIN is caught before contacting the server', (tester) async {
      final auth = FakeAuthRepository()..addDriver('DRV001', '482913');
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a driver"));
      await _enter(tester, 'Driver ID', 'DRV001');
      await _enter(tester, 'PIN', '4829');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

      expect(find.text('PIN must be 6 digits'), findsOneWidget);
      expect(auth.signInCalls, 0);
    });
  });

  group('student', () {
    testWidgets('a non-college email is rejected before contacting the server', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a student"));
      await _enter(tester, 'College email', 'someone@gmail.com');
      await _enter(tester, 'Password', 'whatever123');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

      expect(find.text('Use your college email ending in @cb.students.amrita.edu'), findsOneWidget);
      expect(auth.signInCalls, 0);
    });

    testWidgets('signs up, must verify the email, then lands on the student home', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a student"));
      await _tap(tester, find.text('Create an account'));
      await _enter(tester, 'Full name', 'Asha Raman');
      await _enter(tester, 'College email', _studentEmail);
      await _enter(tester, 'Password', 'bus-pass-123');
      await _enter(tester, 'Confirm password', 'bus-pass-123');
      await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

      expect(find.text('Verify your email'), findsOneWidget);

      // Tapping before opening the link keeps the student here.
      await _tap(tester, find.widgetWithText(FilledButton, "I've verified"));
      expect(find.text('Not verified yet. Open the link in the email first.'), findsOneWidget);

      auth.verifyEmail(_studentEmail);
      await _tap(tester, find.widgetWithText(FilledButton, "I've verified"));

      expect(find.text('Hello, Asha Raman'), findsOneWidget);
      expect(find.text('No route chosen yet'), findsOneWidget);
    });

    testWidgets('a verified student signs in straight to the home screen and can sign out', (tester) async {
      final auth = FakeAuthRepository()..addStudent(_studentEmail, 'bus-pass-123');
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a student"));
      await _enter(tester, 'College email', _studentEmail);
      await _enter(tester, 'Password', 'bus-pass-123');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
      expect(find.text('Hello, Asha'), findsOneWidget);

      await _tap(tester, find.byIcon(Icons.more_vert));
      await _tap(tester, find.text('Sign out'));
      expect(find.text("I'm a student"), findsOneWidget);
    });

    testWidgets('a wrong password shows an error', (tester) async {
      final auth = FakeAuthRepository()..addStudent(_studentEmail, 'bus-pass-123');
      await pumpApp(tester, auth);

      await _tap(tester, find.text("I'm a student"));
      await _enter(tester, 'College email', _studentEmail);
      await _enter(tester, 'Password', 'nope-nope');
      await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));

      expect(find.text('Email or password is wrong'), findsOneWidget);
    });
  });

  testWidgets('the language toggle switches the welcome screen to Tamil', (tester) async {
    await pumpApp(tester, FakeAuthRepository());

    await _tap(tester, find.text('தமிழ்'));

    expect(find.text('நான் மாணவர்'), findsOneWidget);
    expect(find.text('நான் ஓட்டுநர்'), findsOneWidget);
  });
}
