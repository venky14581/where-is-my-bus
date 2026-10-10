enum AuthFailureCode {
  notCollegeEmail,
  invalidDriverId,
  invalidPin,
  wrongCredentials,
  emailInUse,
  weakPassword,
  tooManyAttempts,
  network,
  accountDisabled,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.detail]);

  final AuthFailureCode code;

  /// The underlying error, for logs only. Never shown to the user.
  final Object? detail;

  @override
  String toString() => 'AuthFailure($code${detail == null ? '' : ', $detail'})';
}
