import 'app_user.dart';

sealed class Session {
  const Session();
}

final class SignedOut extends Session {
  const SignedOut();

  @override
  bool operator ==(Object other) => other is SignedOut;

  @override
  int get hashCode => 0;
}

final class SignedIn extends Session {
  const SignedIn({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.profile,
  });

  final String uid;
  final String email;
  final bool emailVerified;

  /// Null when the account has no usable `users/{uid}` document.
  final AppUser? profile;
}
