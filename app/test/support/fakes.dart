import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/app.dart';
import 'package:where_is_my_bus/core/settings_store.dart';
import 'package:where_is_my_bus/features/auth/application/auth_providers.dart';
import 'package:where_is_my_bus/features/auth/data/auth_repository.dart';
import 'package:where_is_my_bus/features/auth/domain/app_user.dart';
import 'package:where_is_my_bus/features/auth/domain/auth_failure.dart';
import 'package:where_is_my_bus/features/auth/domain/credentials.dart';
import 'package:where_is_my_bus/features/auth/domain/session.dart';

class InMemorySettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Account {
  _Account({required this.secret, required this.profile, this.verified = true});

  final String secret;
  AppUser? profile;
  bool verified;
}

/// In-memory stand-in for Firebase that follows the same rules as
/// `FirebaseAuthRepository`: college emails only, driver ID mapped to email.
class FakeAuthRepository implements AuthRepository {
  final _accounts = <String, _Account>{};
  final _changes = StreamController<Session>.broadcast();
  Session _current = const SignedOut();
  String? _currentEmail;
  int signInCalls = 0;

  void addStudent(String email, String password, {String name = 'Asha', bool verified = true}) {
    final uid = 'uid-$email';
    _accounts[email] = _Account(
      secret: password,
      verified: verified,
      profile: AppUser(uid: uid, name: name, role: UserRole.student, email: email, language: 'en'),
    );
  }

  void addDriver(String driverId, String pin, {String name = 'Murugan', String? language}) {
    final email = driverEmailFor(driverId);
    _accounts[email] = _Account(
      secret: pin,
      profile: AppUser(
        uid: 'uid-$driverId',
        name: name,
        role: UserRole.driver,
        driverId: normalizeDriverId(driverId),
        language: language,
      ),
    );
  }

  void addOffice(String email, String password) {
    _accounts[email] = _Account(
      secret: password,
      profile: AppUser(uid: 'uid-$email', name: 'Office', role: UserRole.office, email: email),
    );
  }

  /// Simulates the student opening the link in the verification email.
  void verifyEmail(String email) => _accounts[email]!.verified = true;

  void _emit() {
    final email = _currentEmail;
    final account = email == null ? null : _accounts[email];
    _current = account == null
        ? const SignedOut()
        : SignedIn(
            uid: 'uid-$email',
            email: email!,
            emailVerified: account.verified,
            profile: account.profile,
          );
    _changes.add(_current);
  }

  @override
  Stream<Session> sessions() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signInStudent({required String email, required String password}) async {
    signInCalls++;
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    _signIn(normalized, password);
  }

  @override
  Future<void> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String language,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    if (_accounts.containsKey(normalized)) throw const AuthFailure(AuthFailureCode.emailInUse);
    addStudent(normalized, password, name: name, verified: false);
    _currentEmail = normalized;
    _emit();
  }

  @override
  Future<void> signInDriver({required String driverId, required String pin}) async {
    signInCalls++;
    if (!isValidDriverId(driverId)) throw const AuthFailure(AuthFailureCode.invalidDriverId);
    if (!isValidPin(pin)) throw const AuthFailure(AuthFailureCode.invalidPin);
    _signIn(driverEmailFor(driverId), pin);
  }

  void _signIn(String email, String secret) {
    final account = _accounts[email];
    if (account == null || account.secret != secret) {
      throw const AuthFailure(AuthFailureCode.wrongCredentials);
    }
    _currentEmail = email;
    _emit();
  }

  @override
  Future<void> sendVerificationEmail() async {}

  @override
  Future<bool> refreshEmailVerified() async {
    _emit();
    final current = _current;
    return current is SignedIn && current.emailVerified;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> createStudentProfile({required String name, required String language}) async {
    final account = _accounts[_currentEmail]!;
    account.profile = AppUser(
      uid: 'uid-$_currentEmail',
      name: name,
      role: UserRole.student,
      email: _currentEmail,
      language: language,
    );
    _emit();
  }

  @override
  Future<void> updateLanguage(String languageCode) async {
    final account = _accounts[_currentEmail];
    final profile = account?.profile;
    if (profile == null) return;
    account!.profile = AppUser(
      uid: profile.uid,
      name: profile.name,
      role: profile.role,
      email: profile.email,
      driverId: profile.driverId,
      language: languageCode,
    );
    _emit();
  }

  @override
  Future<void> signOut() async {
    _currentEmail = null;
    _emit();
  }
}

Future<void> pumpApp(WidgetTester tester, FakeAuthRepository auth, {InMemorySettingsStore? settings}) async {
  // A phone-sized surface so layouts match what students and drivers see.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      settingsStoreProvider.overrideWithValue(settings ?? InMemorySettingsStore()),
    ],
    child: const WhereIsMyBusApp(),
  ));
  await tester.pumpAndSettle();
}
