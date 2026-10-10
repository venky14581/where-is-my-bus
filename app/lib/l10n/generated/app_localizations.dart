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

  /// No description provided for @chooseCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you travel from?'**
  String get chooseCityTitle;

  /// No description provided for @chooseRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your route'**
  String get chooseRouteTitle;

  /// No description provided for @chooseStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your stop'**
  String get chooseStopTitle;

  /// No description provided for @chooseStopBody.
  ///
  /// In en, this message translates to:
  /// **'The app opens on this bus every time. You can change it later.'**
  String get chooseStopBody;

  /// No description provided for @stopCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stops'**
  String stopCount(int count);

  /// No description provided for @routeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 route} other{{count} routes}}'**
  String routeCount(int count);

  /// No description provided for @firstPickupAt.
  ///
  /// In en, this message translates to:
  /// **'First pickup {time}'**
  String firstPickupAt(String time);

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @noRoutesYet.
  ///
  /// In en, this message translates to:
  /// **'No routes have been added yet. Check back later.'**
  String get noRoutesYet;

  /// No description provided for @yourStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Your stop'**
  String get yourStopTitle;

  /// No description provided for @busDueAt.
  ///
  /// In en, this message translates to:
  /// **'Bus due at {time}'**
  String busDueAt(String time);

  /// No description provided for @changeButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeButton;

  /// No description provided for @routeMissing.
  ///
  /// In en, this message translates to:
  /// **'Your route or stop is no longer running. Choose another.'**
  String get routeMissing;

  /// No description provided for @chooseRouteButton.
  ///
  /// In en, this message translates to:
  /// **'Choose route'**
  String get chooseRouteButton;

  /// No description provided for @busNumber.
  ///
  /// In en, this message translates to:
  /// **'Bus {number}'**
  String busNumber(String number);

  /// No description provided for @endTrip.
  ///
  /// In en, this message translates to:
  /// **'End Trip'**
  String get endTrip;

  /// No description provided for @endTripConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End this trip?'**
  String get endTripConfirmTitle;

  /// No description provided for @endTripConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Students will stop seeing the bus on the map.'**
  String get endTripConfirmBody;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @directionToCampus.
  ///
  /// In en, this message translates to:
  /// **'Morning trip to campus'**
  String get directionToCampus;

  /// No description provided for @directionFromCampus.
  ///
  /// In en, this message translates to:
  /// **'Evening trip from campus'**
  String get directionFromCampus;

  /// No description provided for @sharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Sharing bus location'**
  String get sharingLocation;

  /// No description provided for @lastSentSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'Sent {seconds} s ago'**
  String lastSentSecondsAgo(int seconds);

  /// No description provided for @waitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS…'**
  String get waitingForGps;

  /// No description provided for @noSignal.
  ///
  /// In en, this message translates to:
  /// **'No signal. The location will be sent when the network returns.'**
  String get noSignal;

  /// No description provided for @nextStopName.
  ///
  /// In en, this message translates to:
  /// **'Next stop: {name}'**
  String nextStopName(String name);

  /// No description provided for @stopsReached.
  ///
  /// In en, this message translates to:
  /// **'{reached} of {total} stops reached'**
  String stopsReached(int reached, int total);

  /// No description provided for @lastStopReached.
  ///
  /// In en, this message translates to:
  /// **'All stops reached. Tap End Trip.'**
  String get lastStopReached;

  /// No description provided for @mockLocationWarning.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS detected. Turn off any fake location app. The bus location is not being sent.'**
  String get mockLocationWarning;

  /// No description provided for @problemLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location is off. Turn it on to start the trip.'**
  String get problemLocationOff;

  /// No description provided for @problemPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The app needs location permission to share the bus position.'**
  String get problemPermissionDenied;

  /// No description provided for @problemPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Allow it in Settings.'**
  String get problemPermissionDeniedForever;

  /// No description provided for @problemStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the trip. Check the internet and try again.'**
  String get problemStartFailed;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @agoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s ago'**
  String agoSeconds(int seconds);

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String agoMinutes(int minutes);

  /// No description provided for @busLive.
  ///
  /// In en, this message translates to:
  /// **'Live · updated {ago}'**
  String busLive(String ago);

  /// No description provided for @busStale.
  ///
  /// In en, this message translates to:
  /// **'Weak signal · last position {ago}'**
  String busStale(String ago);

  /// No description provided for @busOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · last seen at {time}'**
  String busOffline(String time);

  /// No description provided for @busNotRunning.
  ///
  /// In en, this message translates to:
  /// **'The bus isn\'t running right now.'**
  String get busNotRunning;

  /// No description provided for @noBusOnRoute.
  ///
  /// In en, this message translates to:
  /// **'No bus is assigned to this route yet.'**
  String get noBusOnRoute;

  /// No description provided for @followBus.
  ///
  /// In en, this message translates to:
  /// **'Follow the bus'**
  String get followBus;

  /// No description provided for @allBusesTitle.
  ///
  /// In en, this message translates to:
  /// **'All buses'**
  String get allBusesTitle;

  /// No description provided for @allBusesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No buses are running right now.'**
  String get allBusesEmpty;

  /// No description provided for @mapAttribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'Arrives in {minutes} min'**
  String etaMinutes(int minutes);

  /// No description provided for @etaAround.
  ///
  /// In en, this message translates to:
  /// **'around {time}'**
  String etaAround(String time);

  /// No description provided for @arrivingNow.
  ///
  /// In en, this message translates to:
  /// **'The bus is at your stop now'**
  String get arrivingNow;

  /// No description provided for @passedAt.
  ///
  /// In en, this message translates to:
  /// **'Passed your stop at {time}'**
  String passedAt(String time);

  /// No description provided for @passedNoTime.
  ///
  /// In en, this message translates to:
  /// **'The bus has passed your stop'**
  String get passedNoTime;

  /// No description provided for @offRoute.
  ///
  /// In en, this message translates to:
  /// **'The bus is away from its usual route, so there is no arrival time.'**
  String get offRoute;

  /// No description provided for @etaFromLastPosition.
  ///
  /// In en, this message translates to:
  /// **'Estimated from the last known position'**
  String get etaFromLastPosition;

  /// No description provided for @fullRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Full route'**
  String get fullRouteTitle;

  /// No description provided for @fullRouteButton.
  ///
  /// In en, this message translates to:
  /// **'See all stops'**
  String get fullRouteButton;

  /// No description provided for @stopScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {time}'**
  String stopScheduled(String time);

  /// No description provided for @stopPassedAt.
  ///
  /// In en, this message translates to:
  /// **'Passed at {time}'**
  String stopPassedAt(String time);

  /// No description provided for @stopPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get stopPassed;

  /// No description provided for @stopExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected {time}'**
  String stopExpected(String time);

  /// No description provided for @busIsHere.
  ///
  /// In en, this message translates to:
  /// **'Bus is here'**
  String get busIsHere;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts right now. Trip news from the last day and announcements from the last week appear here.'**
  String get alertsEmpty;

  /// No description provided for @alertTripStarted.
  ///
  /// In en, this message translates to:
  /// **'{bus} has started its trip.'**
  String alertTripStarted(String bus);

  /// No description provided for @alertDelay.
  ///
  /// In en, this message translates to:
  /// **'{bus} is running about {minutes} min behind schedule.'**
  String alertDelay(String bus, int minutes);

  /// No description provided for @alertLate.
  ///
  /// In en, this message translates to:
  /// **'The driver of {bus} reports the bus is running late.'**
  String alertLate(String bus);

  /// No description provided for @alertBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{bus} has broken down. Watch for news from the transport office.'**
  String alertBreakdown(String bus);

  /// No description provided for @announcementLabel.
  ///
  /// In en, this message translates to:
  /// **'Transport office'**
  String get announcementLabel;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettingsTitle;

  /// No description provided for @settingApproaching.
  ///
  /// In en, this message translates to:
  /// **'Bus approaching my stop'**
  String get settingApproaching;

  /// No description provided for @settingLeadStops.
  ///
  /// In en, this message translates to:
  /// **'Tell me when it is'**
  String get settingLeadStops;

  /// No description provided for @leadStopsOption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop away} other{{count} stops away}}'**
  String leadStopsOption(int count);

  /// No description provided for @settingTripStarted.
  ///
  /// In en, this message translates to:
  /// **'Bus has started'**
  String get settingTripStarted;

  /// No description provided for @settingDelays.
  ///
  /// In en, this message translates to:
  /// **'Delays and breakdowns'**
  String get settingDelays;

  /// No description provided for @settingAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Transport office announcements'**
  String get settingAnnouncements;

  /// No description provided for @settingQuietDays.
  ///
  /// In en, this message translates to:
  /// **'Quiet days'**
  String get settingQuietDays;

  /// No description provided for @settingQuietDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'No notifications on these days, except breakdowns.'**
  String get settingQuietDaysHelp;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check the internet and try again.'**
  String get settingsSaveFailed;

  /// No description provided for @driverReportLate.
  ///
  /// In en, this message translates to:
  /// **'Running late'**
  String get driverReportLate;

  /// No description provided for @driverReportBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get driverReportBreakdown;

  /// No description provided for @driverReportSent.
  ///
  /// In en, this message translates to:
  /// **'Riders have been told.'**
  String get driverReportSent;

  /// No description provided for @breakdownConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a breakdown?'**
  String get breakdownConfirmTitle;

  /// No description provided for @breakdownConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every rider on this route will be told the bus has broken down.'**
  String get breakdownConfirmBody;

  /// No description provided for @reportButton.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportButton;

  /// No description provided for @myPassTitle.
  ///
  /// In en, this message translates to:
  /// **'My bus pass'**
  String get myPassTitle;

  /// No description provided for @passShowDriver.
  ///
  /// In en, this message translates to:
  /// **'Show this to the driver when you board.'**
  String get passShowDriver;

  /// No description provided for @passValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String passValidUntil(String date);

  /// No description provided for @passExpired.
  ///
  /// In en, this message translates to:
  /// **'Your pass has expired. Contact the transport office.'**
  String get passExpired;

  /// No description provided for @passNone.
  ///
  /// In en, this message translates to:
  /// **'No bus pass on your account. Contact the transport office.'**
  String get passNone;

  /// No description provided for @passPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your pass…'**
  String get passPreparing;

  /// No description provided for @passRefreshesIn.
  ///
  /// In en, this message translates to:
  /// **'Changes in {seconds} s, so screenshots stop working'**
  String passRefreshesIn(int seconds);

  /// No description provided for @scanPassButton.
  ///
  /// In en, this message translates to:
  /// **'Scan pass'**
  String get scanPassButton;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan passes'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the student\'s QR code.'**
  String get scanHint;

  /// No description provided for @boardedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} boarded'**
  String boardedCount(int count);

  /// No description provided for @scanBoarded.
  ///
  /// In en, this message translates to:
  /// **'{name} – boarded'**
  String scanBoarded(String name);

  /// No description provided for @scanAlreadyBoarded.
  ///
  /// In en, this message translates to:
  /// **'{name} already boarded'**
  String scanAlreadyBoarded(String name);

  /// No description provided for @scanNotAPass.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a bus pass.'**
  String get scanNotAPass;

  /// No description provided for @scanInvalid.
  ///
  /// In en, this message translates to:
  /// **'This pass is not genuine.'**
  String get scanInvalid;

  /// No description provided for @scanExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Old code. Ask the student to open their pass again.'**
  String get scanExpiredCode;

  /// No description provided for @scanNoPass.
  ///
  /// In en, this message translates to:
  /// **'{name} has no bus pass.'**
  String scanNoPass(String name);

  /// No description provided for @scanPassExpired.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s pass has expired.'**
  String scanPassExpired(String name);

  /// No description provided for @scanWrongRoute.
  ///
  /// In en, this message translates to:
  /// **'{name} is not allowed on this bus.'**
  String scanWrongRoute(String name);

  /// No description provided for @scanOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the pass by eye for now.'**
  String get scanOffline;

  /// No description provided for @missedBusButton.
  ///
  /// In en, this message translates to:
  /// **'Missed your bus?'**
  String get missedBusButton;

  /// No description provided for @missedBusTitle.
  ///
  /// In en, this message translates to:
  /// **'Catch another bus'**
  String get missedBusTitle;

  /// No description provided for @missedBusIntro.
  ///
  /// In en, this message translates to:
  /// **'College buses the transport office allows you to ride, each with the nearest stop you can reach in time.'**
  String get missedBusIntro;

  /// No description provided for @missedBusFromHere.
  ///
  /// In en, this message translates to:
  /// **'Distances from where you are now.'**
  String get missedBusFromHere;

  /// No description provided for @missedBusFromStop.
  ///
  /// In en, this message translates to:
  /// **'Distances from your stop, {stop}. Allow location to get a closer match.'**
  String missedBusFromStop(String stop);

  /// No description provided for @missedBusLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding where you are…'**
  String get missedBusLocating;

  /// No description provided for @missedBusNone.
  ///
  /// In en, this message translates to:
  /// **'No other college bus can take you right now.'**
  String get missedBusNone;

  /// No description provided for @missedBusNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Only buses the transport office allows for your route, still on their way to a stop near you, are shown here.'**
  String get missedBusNoneHint;

  /// No description provided for @missedBusNeedsPass.
  ///
  /// In en, this message translates to:
  /// **'You need a valid bus pass to ride another college bus.'**
  String get missedBusNeedsPass;

  /// No description provided for @missedBusGetOnAt.
  ///
  /// In en, this message translates to:
  /// **'Get on at {stop}'**
  String missedBusGetOnAt(String stop);

  /// No description provided for @missedBusWalk.
  ///
  /// In en, this message translates to:
  /// **'{distance} walk, about {minutes} min'**
  String missedBusWalk(String distance, int minutes);

  /// No description provided for @missedBusBusIn.
  ///
  /// In en, this message translates to:
  /// **'Bus there in {minutes} min, around {time}'**
  String missedBusBusIn(int minutes, String time);

  /// No description provided for @missedBusBusThereNow.
  ///
  /// In en, this message translates to:
  /// **'The bus is at that stop now'**
  String get missedBusBusThereNow;

  /// No description provided for @missedBusTooFar.
  ///
  /// In en, this message translates to:
  /// **'The bus may get there before you.'**
  String get missedBusTooFar;

  /// No description provided for @missedBusSeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat for other routes} other{{count} seats for other routes}}'**
  String missedBusSeats(int count);

  /// No description provided for @missedBusFull.
  ///
  /// In en, this message translates to:
  /// **'No seats left for other routes'**
  String get missedBusFull;

  /// No description provided for @distanceMetres.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String distanceMetres(int metres);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @holdSeatButton.
  ///
  /// In en, this message translates to:
  /// **'Hold a seat'**
  String get holdSeatButton;

  /// No description provided for @holdHeld.
  ///
  /// In en, this message translates to:
  /// **'Seat held. Be at {stop} and show your pass to the driver.'**
  String holdHeld(String stop);

  /// No description provided for @holdCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Give up seat'**
  String get holdCancelButton;

  /// No description provided for @holdBoarded.
  ///
  /// In en, this message translates to:
  /// **'You boarded this bus.'**
  String get holdBoarded;

  /// No description provided for @holdMissed.
  ///
  /// In en, this message translates to:
  /// **'The bus left {stop}, so your seat was released.'**
  String holdMissed(String stop);

  /// No description provided for @holdFull.
  ///
  /// In en, this message translates to:
  /// **'Sorry, the last seat has just gone.'**
  String get holdFull;

  /// No description provided for @holdPassed.
  ///
  /// In en, this message translates to:
  /// **'The bus has already passed that stop.'**
  String get holdPassed;

  /// No description provided for @holdNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This bus does not take riders from your route.'**
  String get holdNotAllowed;

  /// No description provided for @holdNotRunning.
  ///
  /// In en, this message translates to:
  /// **'This bus is no longer running.'**
  String get holdNotRunning;

  /// No description provided for @holdOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get holdOffline;

  /// No description provided for @waitingRidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Riders from other routes'**
  String get waitingRidersTitle;

  /// No description provided for @waitingRider.
  ///
  /// In en, this message translates to:
  /// **'{name} at {stop}'**
  String waitingRider(String name, String stop);

  /// No description provided for @scanNoSeatHeld.
  ///
  /// In en, this message translates to:
  /// **'{name} has no seat held on this bus. They can hold one in the app.'**
  String scanNoSeatHeld(String name);

  /// No description provided for @eveningSeatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Evening seats'**
  String get eveningSeatsTitle;

  /// No description provided for @eveningSeatsButton.
  ///
  /// In en, this message translates to:
  /// **'Evening seats'**
  String get eveningSeatsButton;

  /// No description provided for @eveningIntro.
  ///
  /// In en, this message translates to:
  /// **'Book a spare seat on a college bus leaving campus this evening or tomorrow. A route\'s pass holders always keep their seats.'**
  String get eveningIntro;

  /// No description provided for @eveningToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get eveningToday;

  /// No description provided for @eveningTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get eveningTomorrow;

  /// No description provided for @eveningNone.
  ///
  /// In en, this message translates to:
  /// **'No evening buses to book yet. Booking opens the evening before.'**
  String get eveningNone;

  /// No description provided for @eveningLeaves.
  ///
  /// In en, this message translates to:
  /// **'Leaves campus at {time}'**
  String eveningLeaves(String time);

  /// No description provided for @fareRupees.
  ///
  /// In en, this message translates to:
  /// **'₹{fare}'**
  String fareRupees(String fare);

  /// No description provided for @seatsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No seats left} =1{1 seat left} other{{count} seats left}}'**
  String seatsLeft(int count);

  /// No description provided for @bookingOpensAt.
  ///
  /// In en, this message translates to:
  /// **'Booking opens at {time}'**
  String bookingOpensAt(String time);

  /// No description provided for @bookingUntil.
  ///
  /// In en, this message translates to:
  /// **'Book until {time}'**
  String bookingUntil(String time);

  /// No description provided for @passCoversBus.
  ///
  /// In en, this message translates to:
  /// **'Your bus pass covers this bus.'**
  String get passCoversBus;

  /// No description provided for @bookSeatButton.
  ///
  /// In en, this message translates to:
  /// **'Book a seat'**
  String get bookSeatButton;

  /// No description provided for @bookedLabel.
  ///
  /// In en, this message translates to:
  /// **'You have a seat on this bus'**
  String get bookedLabel;

  /// No description provided for @chooseDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you get off?'**
  String get chooseDropTitle;

  /// No description provided for @bookForButton.
  ///
  /// In en, this message translates to:
  /// **'Book for ₹{fare}'**
  String bookForButton(String fare);

  /// No description provided for @bookAlready.
  ///
  /// In en, this message translates to:
  /// **'You already have a seat on this bus.'**
  String get bookAlready;

  /// No description provided for @bookFull.
  ///
  /// In en, this message translates to:
  /// **'Sorry, no seats are left.'**
  String get bookFull;

  /// No description provided for @bookNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Booking is not open yet.'**
  String get bookNotOpen;

  /// No description provided for @bookClosed.
  ///
  /// In en, this message translates to:
  /// **'Booking has closed'**
  String get bookClosed;

  /// No description provided for @bookNoGuestSeats.
  ///
  /// In en, this message translates to:
  /// **'This route has no seats to book.'**
  String get bookNoGuestSeats;

  /// No description provided for @bookBadStop.
  ///
  /// In en, this message translates to:
  /// **'Choose another stop.'**
  String get bookBadStop;

  /// No description provided for @bookPaymentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment is not available right now. Try again later.'**
  String get bookPaymentsUnavailable;

  /// No description provided for @bookOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get bookOffline;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled, so the seat was released.'**
  String get paymentCancelled;

  /// No description provided for @paymentExpired.
  ///
  /// In en, this message translates to:
  /// **'Payment took too long, so the seat was released. Book again.'**
  String get paymentExpired;

  /// No description provided for @paymentInvalid.
  ///
  /// In en, this message translates to:
  /// **'The payment could not be confirmed. If money was taken, contact the transport office.'**
  String get paymentInvalid;

  /// No description provided for @demoPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo payment'**
  String get demoPaymentTitle;

  /// No description provided for @demoPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'No money is taken. This stands in for Razorpay while testing.'**
  String get demoPaymentBody;

  /// No description provided for @payButton.
  ///
  /// In en, this message translates to:
  /// **'Pay ₹{amount}'**
  String payButton(String amount);

  /// No description provided for @ticketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your tickets'**
  String get ticketsTitle;

  /// No description provided for @ticketShow.
  ///
  /// In en, this message translates to:
  /// **'Show this to the driver. It works for one scan.'**
  String get ticketShow;

  /// No description provided for @ticketQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Bus ticket'**
  String get ticketQrLabel;

  /// No description provided for @ticketUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get ticketUsed;

  /// No description provided for @ticketGetOff.
  ///
  /// In en, this message translates to:
  /// **'Get off at {stop}'**
  String ticketGetOff(String stop);

  /// No description provided for @pendingUntil.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment. The seat is kept until {time}.'**
  String pendingUntil(String time);

  /// No description provided for @cancelBookingButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBookingButton;

  /// No description provided for @noDailyBusTitle.
  ///
  /// In en, this message translates to:
  /// **'I don\'t take a college bus every day'**
  String get noDailyBusTitle;

  /// No description provided for @noDailyBusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hostellers and own transport: book an evening seat when you need one.'**
  String get noDailyBusSubtitle;

  /// No description provided for @noDailyBusHome.
  ///
  /// In en, this message translates to:
  /// **'You have no daily college bus. When you need a ride home, book a spare evening seat.'**
  String get noDailyBusHome;

  /// No description provided for @chooseDailyRouteButton.
  ///
  /// In en, this message translates to:
  /// **'I take a college bus every day'**
  String get chooseDailyRouteButton;

  /// No description provided for @scanTicketUsed.
  ///
  /// In en, this message translates to:
  /// **'This ticket has already been used.'**
  String get scanTicketUsed;

  /// No description provided for @scanWrongTrip.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s ticket is for another bus.'**
  String scanWrongTrip(String name);

  /// No description provided for @scanNotPaid.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s ticket is not paid.'**
  String scanNotPaid(String name);

  /// No description provided for @leaveBy.
  ///
  /// In en, this message translates to:
  /// **'Leave home by {time}'**
  String leaveBy(String time);

  /// No description provided for @leaveNow.
  ///
  /// In en, this message translates to:
  /// **'Leave now to catch it'**
  String get leaveNow;

  /// No description provided for @usualDelayLate.
  ///
  /// In en, this message translates to:
  /// **'Usually about {minutes} min late on {day}s'**
  String usualDelayLate(int minutes, String day);

  /// No description provided for @usualDelayOnTime.
  ///
  /// In en, this message translates to:
  /// **'Usually on time on {day}s'**
  String usualDelayOnTime(String day);

  /// No description provided for @usualDelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Usual delay at campus'**
  String get usualDelayTitle;

  /// No description provided for @usualDelayRow.
  ///
  /// In en, this message translates to:
  /// **'{day}: {minutes, plural, =0{on time} other{about {minutes} min late}}'**
  String usualDelayRow(String day, int minutes);

  /// No description provided for @crowdSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats available'**
  String get crowdSeats;

  /// No description provided for @crowdFew.
  ///
  /// In en, this message translates to:
  /// **'Few seats left'**
  String get crowdFew;

  /// No description provided for @crowdStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing only'**
  String get crowdStanding;

  /// No description provided for @notRidingLabel.
  ///
  /// In en, this message translates to:
  /// **'Not riding this evening'**
  String get notRidingLabel;

  /// No description provided for @notRidingHelp.
  ///
  /// In en, this message translates to:
  /// **'Another student can book your seat. You can change this until {time}.'**
  String notRidingHelp(String time);

  /// No description provided for @notRidingLocked.
  ///
  /// In en, this message translates to:
  /// **'Booking has closed, so this cannot change now.'**
  String get notRidingLocked;

  /// No description provided for @notRidingSeatTaken.
  ///
  /// In en, this message translates to:
  /// **'Your seat has been booked by someone else, so it cannot be taken back.'**
  String get notRidingSeatTaken;

  /// No description provided for @settingLeaveHome.
  ///
  /// In en, this message translates to:
  /// **'Time to leave home'**
  String get settingLeaveHome;

  /// No description provided for @settingLeaveHomeHelp.
  ///
  /// In en, this message translates to:
  /// **'Set your walk to the stop to be told when to leave.'**
  String get settingLeaveHomeHelp;

  /// No description provided for @settingWalkMinutes.
  ///
  /// In en, this message translates to:
  /// **'Walk from home to my stop'**
  String get settingWalkMinutes;

  /// No description provided for @walkMinutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String walkMinutesValue(int minutes);

  /// No description provided for @walkMinutesNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get walkMinutesNone;
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
