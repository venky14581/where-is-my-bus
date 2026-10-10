import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/auth/domain/app_user.dart';
import 'package:where_is_my_bus/features/auth/domain/session.dart';
import 'package:where_is_my_bus/routing/redirect.dart';
import 'package:where_is_my_bus/routing/routes.dart';

const _studentEmail = 'cb.en.u4cse21001@cb.students.amrita.edu';

AsyncValue<Session> _signedIn({
  String email = _studentEmail,
  bool verified = true,
  UserRole? role,
  String? language = 'en',
}) {
  return AsyncData(SignedIn(
    uid: 'u1',
    email: email,
    emailVerified: verified,
    profile: role == null ? null : AppUser(uid: 'u1', name: 'A', role: role, language: language),
  ));
}

void main() {
  test('waits on the splash screen until the session is known', () {
    expect(redirectFor(const AsyncLoading(), Routes.studentHome), Routes.splash);
    expect(redirectFor(const AsyncLoading(), Routes.splash), isNull);
    expect(redirectFor(AsyncError(Exception('offline'), StackTrace.empty), Routes.welcome), Routes.splash);
  });

  group('signed out', () {
    const signedOut = AsyncData<Session>(SignedOut());

    test('may visit the welcome and sign-in screens', () {
      for (final route in Routes.public) {
        expect(redirectFor(signedOut, route), isNull, reason: route);
      }
    });

    test('is sent to welcome from anything else', () {
      for (final route in [Routes.splash, Routes.studentHome, Routes.driverHome, Routes.studentVerifyEmail]) {
        expect(redirectFor(signedOut, route), Routes.welcome, reason: route);
      }
    });
  });

  group('student', () {
    test('must verify their email before anything else', () {
      final session = _signedIn(role: UserRole.student, verified: false);
      expect(redirectFor(session, Routes.studentHome), Routes.studentVerifyEmail);
      expect(redirectFor(session, Routes.driverHome), Routes.studentVerifyEmail);
      expect(redirectFor(session, Routes.studentVerifyEmail), isNull);
    });

    test('once verified, stays in the student app and never reaches driver screens', () {
      final session = _signedIn(role: UserRole.student);
      expect(redirectFor(session, Routes.studentHome), isNull);
      expect(redirectFor(session, '/student/route'), isNull);
      expect(redirectFor(session, Routes.studentSignIn), Routes.studentHome);
      expect(redirectFor(session, Routes.studentVerifyEmail), Routes.studentHome);
      expect(redirectFor(session, Routes.driverHome), Routes.studentHome);
      expect(redirectFor(session, Routes.driverLanguage), Routes.studentHome);
      expect(redirectFor(session, Routes.welcome), Routes.studentHome);
    });

    test('without a profile finishes setup, except mid sign-up', () {
      final session = _signedIn();
      expect(redirectFor(session, Routes.studentHome), Routes.studentFinishSetup);
      expect(redirectFor(session, Routes.studentFinishSetup), isNull);
      expect(redirectFor(session, Routes.studentSignUp), isNull);
    });
  });

  group('driver', () {
    const driverEmail = 'drv001@drivers.whereismybus.invalid';

    test('picks a language at first login', () {
      final session = _signedIn(email: driverEmail, role: UserRole.driver, language: null);
      expect(redirectFor(session, Routes.driverHome), Routes.driverLanguage);
      expect(redirectFor(session, Routes.driverLanguage), isNull);
    });

    test('stays in the driver app and never reaches student screens', () {
      final session = _signedIn(email: driverEmail, role: UserRole.driver, language: 'ta');
      expect(redirectFor(session, Routes.driverHome), isNull);
      expect(redirectFor(session, Routes.driverLanguage), Routes.driverHome);
      expect(redirectFor(session, Routes.driverSignIn), Routes.driverHome);
      expect(redirectFor(session, Routes.studentHome), Routes.driverHome);
      expect(redirectFor(session, Routes.studentVerifyEmail), Routes.driverHome);
    });

    test('without a profile is told to ask the office', () {
      final session = _signedIn(email: driverEmail);
      expect(redirectFor(session, Routes.driverHome), Routes.accountProblem);
    });
  });

  test('office accounts cannot use the mobile app', () {
    final session = _signedIn(email: 'transport@cb.amrita.edu', role: UserRole.office);
    expect(redirectFor(session, Routes.studentHome), Routes.accountProblem);
    expect(redirectFor(session, Routes.driverHome), Routes.accountProblem);
    expect(redirectFor(session, Routes.accountProblem), isNull);
  });

  test('a non-college account without a profile cannot use the app', () {
    final session = _signedIn(email: 'someone@gmail.com');
    expect(redirectFor(session, Routes.studentHome), Routes.accountProblem);
  });
}
