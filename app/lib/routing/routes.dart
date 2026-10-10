abstract final class Routes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const accountProblem = '/account-problem';

  static const studentHome = '/student';
  static const studentSignIn = '/student/sign-in';
  static const studentSignUp = '/student/sign-up';
  static const studentForgotPassword = '/student/forgot-password';
  static const studentVerifyEmail = '/student/verify-email';
  static const studentFinishSetup = '/student/finish-setup';
  static const studentChooseRoute = '/student/choose-route';
  static const studentAllBuses = '/student/buses';
  static const studentFullRoute = '/student/route';
  static const studentAlerts = '/student/alerts';
  static const studentNotificationSettings = '/student/alerts/settings';
  static const studentPass = '/student/pass';
  static const studentMissedBus = '/student/missed-bus';
  static const studentEveningSeats = '/student/evening';

  static const driverHome = '/driver';
  static const driverSignIn = '/driver/sign-in';
  static const driverLanguage = '/driver/language';
  static const driverScan = '/driver/scan';

  /// Reachable while signed out.
  static const public = {
    welcome,
    studentSignIn,
    studentSignUp,
    studentForgotPassword,
    driverSignIn,
  };

  /// Student routes that are part of signing in rather than the student app.
  static const studentOnboarding = {
    studentSignIn,
    studentSignUp,
    studentForgotPassword,
    studentVerifyEmail,
    studentFinishSetup,
  };

  static bool isUnder(String location, String root) =>
      location == root || location.startsWith('$root/');
}
