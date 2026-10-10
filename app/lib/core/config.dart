/// Deployment values kept in one place so the pilot can change them without
/// hunting through screens. `firestore.rules` repeats the email domains, so
/// change both together.
abstract final class AppConfig {
  /// Students sign in with their college address.
  static const studentEmailDomains = ['cb.students.amrita.edu'];

  /// Drivers sign in with an office-issued ID and PIN. Firebase Auth only
  /// knows email and password, so the ID is mapped onto an address under this
  /// domain. `.invalid` is reserved (RFC 2606) and can never receive mail, so a
  /// password-reset email for a driver account cannot reach anyone.
  static const driverEmailDomain = 'drivers.whereismybus.invalid';

  /// Firebase rejects passwords shorter than 6 characters.
  static const driverPinLength = 6;

  static const minStudentPasswordLength = 8;

  static const supportedLanguageCodes = ['en', 'ta'];

  /// Where parents open a shared trip: the dashboard's hosting address. Set
  /// with `--dart-define=SHARE_BASE_URL=https://<project>.web.app` for a
  /// real project; the default is the dashboard's local dev server.
  static const shareBaseUrl = String.fromEnvironment('SHARE_BASE_URL', defaultValue: 'http://localhost:5173');

  static String shareLink(String token) => '$shareBaseUrl/#/share/$token';
}
