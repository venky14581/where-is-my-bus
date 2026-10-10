import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Where Is My Bus'**
  String get appTitle;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Live college bus tracking for Amrita Coimbatore'**
  String get welcomeTagline;

  /// No description provided for @welcomeStudentTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m a student'**
  String get welcomeStudentTitle;

  /// No description provided for @welcomeStudentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your bus and see when it reaches your stop'**
  String get welcomeStudentSubtitle;

  /// No description provided for @welcomeDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m a driver'**
  String get welcomeDriverTitle;

  /// No description provided for @welcomeDriverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start and end your trip'**
  String get welcomeDriverSubtitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @studentSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Student sign in'**
  String get studentSignInTitle;

  /// No description provided for @collegeEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'College email'**
  String get collegeEmailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get noAccountPrompt;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccountLink;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// No description provided for @studentSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get studentSignUpTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Open it, then come back and tap \"I\'ve verified\".'**
  String verifyEmailBody(String email);

  /// No description provided for @verifiedButton.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get verifiedButton;

  /// No description provided for @resendEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmailButton;

  /// No description provided for @resendEmailWait.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendEmailWait(int seconds);

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verificationEmailSent;

  /// No description provided for @notVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in the email first.'**
  String get notVerifiedYet;

  /// No description provided for @useDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get useDifferentAccount;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your college email and we\'ll send you a link to set a new password.'**
  String get forgotPasswordBody;

  /// No description provided for @sendResetLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLinkButton;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'If {email} has an account, a reset link is on its way.'**
  String resetLinkSent(String email);

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @finishSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up'**
  String get finishSetupTitle;

  /// No description provided for @finishSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us your name to finish creating your account.'**
  String get finishSetupBody;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @driverSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver sign in'**
  String get driverSignInTitle;

  /// No description provided for @driverIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver ID'**
  String get driverIdLabel;

  /// No description provided for @driverIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. DRV001'**
  String get driverIdHint;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @driverSignInHelp.
  ///
  /// In en, this message translates to:
  /// **'Your driver ID and {length}-digit PIN come from the transport office.'**
  String driverSignInHelp(int length);

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'You can change this later from the menu.'**
  String get chooseLanguageBody;

  /// No description provided for @helloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloName(String name);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get startTrip;

  /// No description provided for @busNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'No bus assigned yet. The transport office will assign your bus.'**
  String get busNotAssigned;

  /// No description provided for @driverIdValue.
  ///
  /// In en, this message translates to:
  /// **'Driver ID: {id}'**
  String driverIdValue(String id);

  /// No description provided for @routeNotChosenTitle.
  ///
  /// In en, this message translates to:
  /// **'No route chosen yet'**
  String get routeNotChosenTitle;

  /// No description provided for @routeNotChosenBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll pick your city, route and stop here. After that the app opens on your bus every time.'**
  String get routeNotChosenBody;

  /// No description provided for @accountProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this account'**
  String get accountProblemTitle;

  /// No description provided for @accountProblemDriverNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'This driver ID isn\'t set up yet. Ask the transport office to finish it.'**
  String get accountProblemDriverNotSetUp;

  /// No description provided for @accountProblemOffice.
  ///
  /// In en, this message translates to:
  /// **'Transport office accounts use the web dashboard, not the app.'**
  String get accountProblemOffice;

  /// No description provided for @accountProblemGeneric.
  ///
  /// In en, this message translates to:
  /// **'This account can\'t use the app. Students sign in with their college email.'**
  String get accountProblemGeneric;

  /// No description provided for @startupError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your internet and try again.'**
  String get startupError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get errorRequired;

  /// No description provided for @errorNotCollegeEmail.
  ///
  /// In en, this message translates to:
  /// **'Use your college email ending in @{domain}'**
  String errorNotCollegeEmail(String domain);

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters'**
  String errorPasswordTooShort(int min);

  /// No description provided for @errorPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get errorPasswordsDontMatch;

  /// No description provided for @errorInvalidDriverId.
  ///
  /// In en, this message translates to:
  /// **'Check the driver ID: letters and numbers only'**
  String get errorInvalidDriverId;

  /// No description provided for @errorInvalidPin.
  ///
  /// In en, this message translates to:
  /// **'PIN must be {length} digits'**
  String errorInvalidPin(int length);

  /// No description provided for @errorWrongStudentCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is wrong'**
  String get errorWrongStudentCredentials;

  /// No description provided for @errorWrongDriverCredentials.
  ///
  /// In en, this message translates to:
  /// **'Driver ID or PIN is wrong'**
  String get errorWrongDriverCredentials;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Sign in instead.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password'**
  String get errorWeakPassword;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetwork;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Contact the transport office.'**
  String get errorAccountDisabled;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
