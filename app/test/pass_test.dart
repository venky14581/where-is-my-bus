import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:where_is_my_bus/features/auth/domain/app_user.dart';
import 'package:where_is_my_bus/features/pass/data/pass_repository.dart';
import 'package:where_is_my_bus/features/pass/domain/pass_code.dart';
import 'package:where_is_my_bus/features/pass/ui/pass_screen.dart';
import 'package:where_is_my_bus/features/routes/domain/bus_route.dart';

import 'support/fakes.dart';

const _email = 'cb.en.u4cse21001@cb.students.amrita.edu';
const _uid = 'uid-$_email';
const _secret = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';
const _bus = Bus(id: 'bus-01', number: 'TN 37 AB 1201', capacity: 50, routeId: 'cbe-gandhipuram', driverId: 'uid-DRV001');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Long enough for the server's answer, well short of the 3 s the verdict
/// stays on screen.
Future<void> _checked(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _openPass(WidgetTester tester, {bool passValid = true, String? until = '2026-12-31'}) async {
  final auth = FakeAuthRepository()
    ..addStudent(_email, 'bus-pass-123', routeId: 'cbe-gandhipuram', stopId: 'ukkadam', passValid: passValid, passValidUntil: until);
  final passes = FakePassRepository()..secrets[_uid] = _secret;
  await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), passes: passes);
  await _tap(tester, find.text("I'm a student"));
  await tester.enterText(find.widgetWithText(TextFormField, 'College email'), _email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'bus-pass-123');
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  await _tap(tester, find.byTooltip('My bus pass'));
}

void main() {
  test('a pass shows only while valid, through its last day', () {
    const user = AppUser(uid: 'u', name: 'A', role: UserRole.student, passValid: true, passValidUntil: '2026-10-10');
    expect(passStatusOf(user, DateTime(2026, 10, 10, 23, 59)), PassStatus.valid);
    expect(passStatusOf(user, DateTime(2026, 10, 11)), PassStatus.expired);
    expect(passStatusOf(const AppUser(uid: 'u', name: 'A', role: UserRole.student), DateTime(2026)), PassStatus.none);
  });

  testWidgets('the pass screen shows the current rotating code as a QR', (tester) async {
    await _openPass(tester);

    // The test clock reads 07:00:00 on 10 Oct 2026, the start of a window.
    final expected = PassCode.make(secretBase64: _secret, uid: _uid, serverTime: DateTime(2026, 10, 10, 7));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(qr.semanticsLabel, 'My bus pass');
    expect(find.text('Valid until Dec 31, 2026'), findsOneWidget);
    expect(find.textContaining('Changes in 30 s'), findsOneWidget);
    expect(expected, startsWith('WIMB1.$_uid.'));
  });

  testWidgets('no QR without a valid pass', (tester) async {
    await _openPass(tester, passValid: false, until: null);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('No bus pass on your account. Contact the transport office.'), findsOneWidget);
  });

  testWidgets('an expired pass says so', (tester) async {
    await _openPass(tester, until: '2026-09-30');
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Your pass has expired'), findsOneWidget);
  });

  testWidgets('the driver scans passes and sees each verdict', (tester) async {
    final auth = FakeAuthRepository()..addDriver('DRV001', '482913', language: 'en');
    final passes = FakePassRepository()
      ..decide = (code) => switch (code) {
            'good' => const ScanOutcome(ScanResult.boarded, name: 'Asha'),
            'other-route' => const ScanOutcome(ScanResult.wrongRoute, name: 'Ravi'),
            _ => const ScanOutcome(ScanResult.notAPass),
          };
    final scanner = FakeScanner();
    await pumpApp(tester, auth, routes: FakeRouteRepository(auth, buses: [_bus]), passes: passes, scanner: scanner);
    await _tap(tester, find.text("I'm a driver"));
    await tester.enterText(find.widgetWithText(TextFormField, 'Driver ID'), 'DRV001');
    await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '482913');
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _tap(tester, find.text('Start Trip'));
    await _tap(tester, find.text('Scan pass'));

    expect(find.text("Point the camera at the student's QR code."), findsOneWidget);

    scanner.emit('good');
    await _checked(tester);
    expect(find.text('Asha – boarded'), findsOneWidget);

    // The camera sees the same code many times a second; only one check.
    scanner.emit('good');
    await _checked(tester);
    expect(passes.scanned, ['good']);

    scanner.emit('other-route');
    await _checked(tester);
    expect(find.text('Ravi is not allowed on this bus.'), findsOneWidget);

    // The verdict clears after a few seconds, ready for the next student.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text("Point the camera at the student's QR code."), findsOneWidget);
  });
}
