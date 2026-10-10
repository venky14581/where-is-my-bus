import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import '../domain/session.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  @override
  Stream<Session> sessions() {
    late final StreamController<Session> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profileSub;
    var seenFirstEvent = false;
    String? currentUid;
    DocumentSnapshot<Map<String, dynamic>>? lastProfile;

    void emit(User user) {
      final snap = lastProfile;
      if (snap == null) return;
      controller.add(SignedIn(
        uid: user.uid,
        email: user.email ?? '',
        emailVerified: user.emailVerified,
        profile: snap.exists ? AppUser.tryFromMap(user.uid, snap.data()!) : null,
      ));
    }

    // idTokenChanges also fires after the forced token refresh in
    // refreshEmailVerified, which is how a verified email reaches the session.
    void onUser(User? user) {
      // Same user as before: a token refresh, so only the verified flag can
      // have changed. The first event always goes through, including a
      // signed-out start where both uids are null.
      if (seenFirstEvent && user?.uid == currentUid) {
        if (user != null) emit(user);
        return;
      }
      seenFirstEvent = true;
      profileSub?.cancel();
      profileSub = null;
      lastProfile = null;
      currentUid = user?.uid;
      if (user == null) {
        controller.add(const SignedOut());
        return;
      }
      profileSub = _users.doc(user.uid).snapshots(includeMetadataChanges: true).listen(
        (snap) {
          // Offline, a missing document is indistinguishable from one the
          // cache hasn't seen yet. Wait for the server rather than sending
          // the user to the finish-setup screen by mistake.
          if (!snap.exists && snap.metadata.isFromCache) return;
          lastProfile = snap;
          emit(_auth.currentUser ?? user);
        },
        onError: controller.addError,
      );
    }

    controller = StreamController<Session>(
      onListen: () {
        authSub = _auth.idTokenChanges().listen(onUser, onError: controller.addError);
      },
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> signInStudent({required String email, required String password}) async {
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) {
      throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    }
    await _guard(() => _auth.signInWithEmailAndPassword(email: normalized, password: password));
  }

  @override
  Future<void> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String language,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) {
      throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    }
    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(email: normalized, password: password),
    );
    final user = credential.user!;
    await _guard(() => _writeStudentProfile(user, name: name, language: language));
    await _guard(() => user.sendEmailVerification());
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _guard(() => user.sendEmailVerification());
  }

  @override
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await _guard(() => user.reload());
    final fresh = _auth.currentUser!;
    if (fresh.emailVerified) await _guard(() => fresh.getIdToken(true));
    return fresh.emailVerified;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final normalized = normalizeEmail(email);
    if (!isCollegeStudentEmail(normalized)) {
      throw const AuthFailure(AuthFailureCode.notCollegeEmail);
    }
    await _guard(() => _auth.sendPasswordResetEmail(email: normalized));
  }

  @override
  Future<void> createStudentProfile({required String name, required String language}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _guard(() => _writeStudentProfile(user, name: name, language: language));
  }

  Future<void> _writeStudentProfile(User user, {required String name, required String language}) {
    // firestore.rules checks every one of these fields on create.
    return _users.doc(user.uid).set({
      'name': name.trim(),
      'email': normalizeEmail(user.email ?? ''),
      'role': UserRole.student.name,
      'routeId': null,
      'stopId': null,
      'passValid': false,
      'language': language,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> signInDriver({required String driverId, required String pin}) async {
    if (!isValidDriverId(driverId)) throw const AuthFailure(AuthFailureCode.invalidDriverId);
    if (!isValidPin(pin)) throw const AuthFailure(AuthFailureCode.invalidPin);
    // A driver ID without a driver profile is caught by the router, which
    // sends the user to the account-problem screen.
    await _guard(
      () => _auth.signInWithEmailAndPassword(email: driverEmailFor(driverId), password: pin),
    );
  }

  @override
  Future<void> updateLanguage(String languageCode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _guard(() => _users.doc(user.uid).update({'language': languageCode}));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_codeFor(e.code), e);
    } on FirebaseException catch (e) {
      throw AuthFailure(
        e.code == 'unavailable' ? AuthFailureCode.network : AuthFailureCode.unknown,
        e,
      );
    }
  }

  static AuthFailureCode _codeFor(String firebaseCode) => switch (firebaseCode) {
        'invalid-email' => AuthFailureCode.notCollegeEmail,
        // invalid-credential replaces the other two when email enumeration
        // protection is on, which is the default for new projects.
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          AuthFailureCode.wrongCredentials,
        'email-already-in-use' => AuthFailureCode.emailInUse,
        'weak-password' => AuthFailureCode.weakPassword,
        'too-many-requests' => AuthFailureCode.tooManyAttempts,
        'network-request-failed' => AuthFailureCode.network,
        'user-disabled' => AuthFailureCode.accountDisabled,
        _ => AuthFailureCode.unknown,
      };
}
