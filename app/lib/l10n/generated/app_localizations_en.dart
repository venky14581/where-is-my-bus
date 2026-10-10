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
  String get routeNotChosenTitle => 'No route chosen yet';

  @override
  String get routeNotChosenBody =>
      'You\'ll pick your city, route and stop here. After that the app opens on your bus every time.';

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
}
