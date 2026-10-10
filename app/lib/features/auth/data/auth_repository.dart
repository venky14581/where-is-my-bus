import '../domain/session.dart';

/// Everything the app needs from the login backend. Methods throw
/// `AuthFailure` for anything the user can act on.
abstract interface class AuthRepository {
  /// Emits the current session, then every change: sign in or out, email
  /// verification, and edits to the signed-in user's profile document.
  Stream<Session> sessions();

  Future<void> signInStudent({required String email, required String password});

  /// Creates the account and its student profile, then sends the
  /// verification email.
  Future<void> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String language,
  });

  Future<void> sendVerificationEmail();

  /// Re-checks the verification state with the server. When verified, also
  /// refreshes the ID token so security rules see `email_verified`.
  Future<bool> refreshEmailVerified();

  Future<void> sendPasswordReset(String email);

  /// For a signed-in college account that has no profile document yet.
  Future<void> createStudentProfile({required String name, required String language});

  Future<void> signInDriver({required String driverId, required String pin});

  /// Saves the language on the signed-in user's profile. No-op when signed out.
  Future<void> updateLanguage(String languageCode);

  Future<void> signOut();
}
