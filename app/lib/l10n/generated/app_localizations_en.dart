// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Where Is My Bus';

  @override
  String get welcomeTagline =>
      'Live college bus tracking for Amrita Coimbatore';

  @override
  String get welcomeStudentTitle => 'I\'m a student';

  @override
  String get welcomeStudentSubtitle =>
      'Track your bus and see when it reaches your stop';

  @override
  String get welcomeDriverTitle => 'I\'m a driver';

  @override
  String get welcomeDriverSubtitle => 'Start and end your trip';

  @override
  String get languageLabel => 'Language';

  @override
  String get studentSignInTitle => 'Student sign in';

  @override
  String get collegeEmailLabel => 'College email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get noAccountPrompt => 'New here?';

  @override
  String get createAccountLink => 'Create an account';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get studentSignUpTitle => 'Create your account';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a link to $email. Open it, then come back and tap \"I\'ve verified\".';
  }

  @override
  String get verifiedButton => 'I\'ve verified';

  @override
  String get resendEmailButton => 'Resend email';

  @override
  String resendEmailWait(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verificationEmailSent => 'Verification email sent.';

  @override
  String get notVerifiedYet =>
      'Not verified yet. Open the link in the email first.';

  @override
  String get useDifferentAccount => 'Use a different account';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordBody =>
      'Enter your college email and we\'ll send you a link to set a new password.';

  @override
  String get sendResetLinkButton => 'Send reset link';

  @override
  String resetLinkSent(String email) {
    return 'If $email has an account, a reset link is on its way.';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get finishSetupTitle => 'Finish setting up';

  @override
  String get finishSetupBody =>
      'Tell us your name to finish creating your account.';

  @override
  String get continueButton => 'Continue';

  @override
  String get driverSignInTitle => 'Driver sign in';

  @override
  String get driverIdLabel => 'Driver ID';

  @override
  String get driverIdHint => 'e.g. DRV001';

  @override
  String get pinLabel => 'PIN';

  @override
  String driverSignInHelp(int length) {
    return 'Your driver ID and $length-digit PIN come from the transport office.';
  }

  @override
  String get chooseLanguageTitle => 'Choose your language';

  @override
  String get chooseLanguageBody => 'You can change this later from the menu.';

  @override
  String helloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get busNotAssigned =>
      'No bus assigned yet. The transport office will assign your bus.';

  @override
  String driverIdValue(String id) {
    return 'Driver ID: $id';
  }

  @override
  String get accountProblemTitle => 'Can\'t open this account';

  @override
  String get accountProblemDriverNotSetUp =>
      'This driver ID isn\'t set up yet. Ask the transport office to finish it.';

  @override
  String get accountProblemOffice =>
      'Transport office accounts use the web dashboard, not the app.';

  @override
  String get accountProblemGeneric =>
      'This account can\'t use the app. Students sign in with their college email.';

  @override
  String get startupError =>
      'Couldn\'t connect. Check your internet and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get errorRequired => 'Required';

  @override
  String errorNotCollegeEmail(String domain) {
    return 'Use your college email ending in @$domain';
  }

  @override
  String errorPasswordTooShort(int min) {
    return 'Use at least $min characters';
  }

  @override
  String get errorPasswordsDontMatch => 'Passwords don\'t match';

  @override
  String get errorInvalidDriverId =>
      'Check the driver ID: letters and numbers only';

  @override
  String errorInvalidPin(int length) {
    return 'PIN must be $length digits';
  }

  @override
  String get errorWrongStudentCredentials => 'Email or password is wrong';

  @override
  String get errorWrongDriverCredentials => 'Driver ID or PIN is wrong';

  @override
  String get errorEmailInUse =>
      'An account already exists for this email. Sign in instead.';

  @override
  String get errorWeakPassword => 'Choose a stronger password';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get errorAccountDisabled =>
      'This account is disabled. Contact the transport office.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String get chooseCityTitle => 'Where do you travel from?';

  @override
  String get chooseRouteTitle => 'Choose your route';

  @override
  String get chooseStopTitle => 'Choose your stop';

  @override
  String get chooseStopBody =>
      'The app opens on this bus every time. You can change it later.';

  @override
  String stopCount(int count) {
    return '$count stops';
  }

  @override
  String routeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routes',
      one: '1 route',
    );
    return '$_temp0';
  }

  @override
  String firstPickupAt(String time) {
    return 'First pickup $time';
  }

  @override
  String get saveButton => 'Save';

  @override
  String get noRoutesYet => 'No routes have been added yet. Check back later.';

  @override
  String get yourStopTitle => 'Your stop';

  @override
  String busDueAt(String time) {
    return 'Bus due at $time';
  }

  @override
  String get changeButton => 'Change';

  @override
  String get routeMissing =>
      'Your route or stop is no longer running. Choose another.';

  @override
  String get chooseRouteButton => 'Choose route';

  @override
  String busNumber(String number) {
    return 'Bus $number';
  }

  @override
  String get endTrip => 'End Trip';

  @override
  String get endTripConfirmTitle => 'End this trip?';

  @override
  String get endTripConfirmBody =>
      'Students will stop seeing the bus on the map.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get directionToCampus => 'Morning trip to campus';

  @override
  String get directionFromCampus => 'Evening trip from campus';

  @override
  String get sharingLocation => 'Sharing bus location';

  @override
  String lastSentSecondsAgo(int seconds) {
    return 'Sent $seconds s ago';
  }

  @override
  String get waitingForGps => 'Waiting for GPS…';

  @override
  String get noSignal =>
      'No signal. The location will be sent when the network returns.';

  @override
  String nextStopName(String name) {
    return 'Next stop: $name';
  }

  @override
  String stopsReached(int reached, int total) {
    return '$reached of $total stops reached';
  }

  @override
  String get lastStopReached => 'All stops reached. Tap End Trip.';

  @override
  String get mockLocationWarning =>
      'Fake GPS detected. Turn off any fake location app. The bus location is not being sent.';

  @override
  String get problemLocationOff =>
      'Location is off. Turn it on to start the trip.';

  @override
  String get problemPermissionDenied =>
      'The app needs location permission to share the bus position.';

  @override
  String get problemPermissionDeniedForever =>
      'Location permission is blocked. Allow it in Settings.';

  @override
  String get problemStartFailed =>
      'Couldn\'t start the trip. Check the internet and try again.';

  @override
  String get openSettings => 'Open settings';

  @override
  String agoSeconds(int seconds) {
    return '$seconds s ago';
  }

  @override
  String agoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String busLive(String ago) {
    return 'Live · updated $ago';
  }

  @override
  String busStale(String ago) {
    return 'Weak signal · last position $ago';
  }

  @override
  String busOffline(String time) {
    return 'Offline · last seen at $time';
  }

  @override
  String get busNotRunning => 'The bus isn\'t running right now.';

  @override
  String get noBusOnRoute => 'No bus is assigned to this route yet.';

  @override
  String get followBus => 'Follow the bus';

  @override
  String get allBusesTitle => 'All buses';

  @override
  String get allBusesEmpty => 'No buses are running right now.';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';
}
