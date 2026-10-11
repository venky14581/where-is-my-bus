// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'என் பேருந்து எங்கே';

  @override
  String get welcomeTagline =>
      'அமிர்தா கோவை கல்லூரிப் பேருந்தின் நேரடி இருப்பிடம்';

  @override
  String get welcomeStudentTitle => 'நான் மாணவர்';

  @override
  String get welcomeStudentSubtitle =>
      'உங்கள் பேருந்தைக் கண்காணித்து, அது உங்கள் நிறுத்தத்தை அடையும் நேரத்தைப் பாருங்கள்';

  @override
  String get welcomeDriverTitle => 'நான் ஓட்டுநர்';

  @override
  String get welcomeDriverSubtitle => 'உங்கள் பயணத்தைத் தொடங்கி முடியுங்கள்';

  @override
  String get languageLabel => 'மொழி';

  @override
  String get studentSignInTitle => 'மாணவர் உள்நுழைவு';

  @override
  String get collegeEmailLabel => 'கல்லூரி மின்னஞ்சல்';

  @override
  String get passwordLabel => 'கடவுச்சொல்';

  @override
  String get confirmPasswordLabel => 'கடவுச்சொல்லை உறுதிப்படுத்தவும்';

  @override
  String get showPassword => 'கடவுச்சொல்லைக் காட்டு';

  @override
  String get hidePassword => 'கடவுச்சொல்லை மறை';

  @override
  String get signInButton => 'உள்நுழை';

  @override
  String get forgotPasswordLink => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get noAccountPrompt => 'புதியவரா?';

  @override
  String get createAccountLink => 'கணக்கை உருவாக்கு';

  @override
  String get haveAccountPrompt => 'ஏற்கனவே கணக்கு உள்ளதா?';

  @override
  String get studentSignUpTitle => 'உங்கள் கணக்கை உருவாக்குங்கள்';

  @override
  String get fullNameLabel => 'முழுப் பெயர்';

  @override
  String get createAccountButton => 'கணக்கை உருவாக்கு';

  @override
  String get verifyEmailTitle => 'உங்கள் மின்னஞ்சலைச் சரிபார்க்கவும்';

  @override
  String verifyEmailBody(String email) {
    return '$email முகவரிக்கு ஓர் இணைப்பை அனுப்பியுள்ளோம். அதைத் திறந்த பிறகு இங்கே வந்து \"சரிபார்த்துவிட்டேன்\" என்பதைத் தட்டவும்.';
  }

  @override
  String get verifiedButton => 'சரிபார்த்துவிட்டேன்';

  @override
  String get resendEmailButton => 'மீண்டும் அனுப்பு';

  @override
  String resendEmailWait(int seconds) {
    return '$seconds வினாடிகளில் மீண்டும் அனுப்பலாம்';
  }

  @override
  String get verificationEmailSent => 'சரிபார்ப்பு மின்னஞ்சல் அனுப்பப்பட்டது.';

  @override
  String get notVerifiedYet =>
      'இன்னும் சரிபார்க்கப்படவில்லை. முதலில் மின்னஞ்சலில் உள்ள இணைப்பைத் திறக்கவும்.';

  @override
  String get useDifferentAccount => 'வேறு கணக்கைப் பயன்படுத்து';

  @override
  String get forgotPasswordTitle => 'கடவுச்சொல்லை மீட்டமை';

  @override
  String get forgotPasswordBody =>
      'உங்கள் கல்லூரி மின்னஞ்சலை உள்ளிடுங்கள். புதிய கடவுச்சொல்லை அமைக்க ஓர் இணைப்பை அனுப்புவோம்.';

  @override
  String get sendResetLinkButton => 'இணைப்பை அனுப்பு';

  @override
  String resetLinkSent(String email) {
    return '$email முகவரிக்குக் கணக்கு இருந்தால், மீட்டமைப்பு இணைப்பு அனுப்பப்படும்.';
  }

  @override
  String get backToSignIn => 'உள்நுழைவுக்குத் திரும்பு';

  @override
  String get finishSetupTitle => 'அமைப்பை முடிக்கவும்';

  @override
  String get finishSetupBody =>
      'உங்கள் கணக்கை உருவாக்கி முடிக்க உங்கள் பெயரை உள்ளிடுங்கள்.';

  @override
  String get continueButton => 'தொடர்க';

  @override
  String get driverSignInTitle => 'ஓட்டுநர் உள்நுழைவு';

  @override
  String get driverIdLabel => 'ஓட்டுநர் எண்';

  @override
  String get driverIdHint => 'எ.கா. DRV001';

  @override
  String get pinLabel => 'ரகசிய எண் (PIN)';

  @override
  String driverSignInHelp(int length) {
    return 'உங்கள் ஓட்டுநர் எண்ணையும் $length இலக்க ரகசிய எண்ணையும் போக்குவரத்து அலுவலகம் வழங்கும்.';
  }

  @override
  String get chooseLanguageTitle => 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get chooseLanguageBody => 'இதைப் பின்னர் பட்டியலில் மாற்றலாம்.';

  @override
  String helloName(String name) {
    return 'வணக்கம், $name';
  }

  @override
  String get signOut => 'வெளியேறு';

  @override
  String get startTrip => 'பயணத்தைத் தொடங்கு';

  @override
  String get busNotAssigned =>
      'இன்னும் பேருந்து ஒதுக்கப்படவில்லை. போக்குவரத்து அலுவலகம் உங்கள் பேருந்தை ஒதுக்கும்.';

  @override
  String driverIdValue(String id) {
    return 'ஓட்டுநர் எண்: $id';
  }

  @override
  String get accountProblemTitle => 'இந்தக் கணக்கைத் திறக்க முடியவில்லை';

  @override
  String get accountProblemDriverNotSetUp =>
      'இந்த ஓட்டுநர் எண் இன்னும் அமைக்கப்படவில்லை. போக்குவரத்து அலுவலகத்திடம் கேளுங்கள்.';

  @override
  String get accountProblemOffice =>
      'போக்குவரத்து அலுவலகக் கணக்குகள் இணைய டாஷ்போர்டைப் பயன்படுத்த வேண்டும், இந்தச் செயலியை அல்ல.';

  @override
  String get accountProblemGeneric =>
      'இந்தக் கணக்கு இந்தச் செயலியைப் பயன்படுத்த முடியாது. மாணவர்கள் கல்லூரி மின்னஞ்சலுடன் உள்நுழைய வேண்டும்.';

  @override
  String get startupError =>
      'இணைக்க முடியவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String get retry => 'மீண்டும் முயல்';

  @override
  String get errorRequired => 'தேவை';

  @override
  String errorNotCollegeEmail(String domain) {
    return '@$domain என முடியும் கல்லூரி மின்னஞ்சலைப் பயன்படுத்தவும்';
  }

  @override
  String errorPasswordTooShort(int min) {
    return 'குறைந்தது $min எழுத்துகள் தேவை';
  }

  @override
  String get errorPasswordsDontMatch => 'கடவுச்சொற்கள் பொருந்தவில்லை';

  @override
  String get errorInvalidDriverId =>
      'ஓட்டுநர் எண்ணைச் சரிபார்க்கவும்: எழுத்துகளும் எண்களும் மட்டும்';

  @override
  String errorInvalidPin(int length) {
    return 'ரகசிய எண் $length இலக்கங்களாக இருக்க வேண்டும்';
  }

  @override
  String get errorWrongStudentCredentials =>
      'மின்னஞ்சல் அல்லது கடவுச்சொல் தவறு';

  @override
  String get errorWrongDriverCredentials =>
      'ஓட்டுநர் எண் அல்லது ரகசிய எண் தவறு';

  @override
  String get errorEmailInUse =>
      'இந்த மின்னஞ்சலுக்கு ஏற்கனவே கணக்கு உள்ளது. உள்நுழையவும்.';

  @override
  String get errorWeakPassword => 'வலுவான கடவுச்சொல்லைத் தேர்ந்தெடுக்கவும்';

  @override
  String get errorTooManyAttempts =>
      'பல முறை முயன்றுவிட்டீர்கள். சில நிமிடங்கள் கழித்து மீண்டும் முயலவும்.';

  @override
  String get errorNetwork => 'இணைய இணைப்பு இல்லை';

  @override
  String get errorAccountDisabled =>
      'இந்தக் கணக்கு முடக்கப்பட்டுள்ளது. போக்குவரத்து அலுவலகத்தைத் தொடர்புகொள்ளவும்.';

  @override
  String get errorUnknown => 'ஏதோ தவறு நடந்தது. மீண்டும் முயலவும்.';

  @override
  String get chooseCityTitle => 'எங்கிருந்து பயணம் செய்கிறீர்கள்?';

  @override
  String get chooseRouteTitle => 'உங்கள் வழித்தடத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get chooseStopTitle => 'உங்கள் நிறுத்தத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get chooseStopBody =>
      'செயலி ஒவ்வொரு முறையும் இந்தப் பேருந்தையே காட்டும். பின்னர் மாற்றலாம்.';

  @override
  String stopCount(int count) {
    return '$count நிறுத்தங்கள்';
  }

  @override
  String routeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count வழித்தடங்கள்',
      one: '1 வழித்தடம்',
    );
    return '$_temp0';
  }

  @override
  String firstPickupAt(String time) {
    return 'முதல் ஏற்றம் $time';
  }

  @override
  String get saveButton => 'சேமி';

  @override
  String get noRoutesYet =>
      'இன்னும் வழித்தடங்கள் சேர்க்கப்படவில்லை. பின்னர் பார்க்கவும்.';

  @override
  String get yourStopTitle => 'உங்கள் நிறுத்தம்';

  @override
  String busDueAt(String time) {
    return 'பேருந்து வரும் நேரம் $time';
  }

  @override
  String get changeButton => 'மாற்று';

  @override
  String get routeMissing =>
      'உங்கள் வழித்தடம் அல்லது நிறுத்தம் இப்போது இயங்கவில்லை. வேறொன்றைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get chooseRouteButton => 'வழித்தடத்தைத் தேர்ந்தெடு';

  @override
  String busNumber(String number) {
    return 'பேருந்து $number';
  }

  @override
  String get endTrip => 'பயணத்தை முடி';

  @override
  String get endTripConfirmTitle => 'இந்தப் பயணத்தை முடிக்கவா?';

  @override
  String get endTripConfirmBody =>
      'மாணவர்கள் இனி வரைபடத்தில் பேருந்தைப் பார்க்க முடியாது.';

  @override
  String get cancelButton => 'ரத்து';

  @override
  String get directionToCampus => 'காலைப் பயணம்: கல்லூரிக்கு';

  @override
  String get directionFromCampus => 'மாலைப் பயணம்: கல்லூரியிலிருந்து';

  @override
  String get sharingLocation => 'பேருந்தின் இருப்பிடம் பகிரப்படுகிறது';

  @override
  String lastSentSecondsAgo(int seconds) {
    return '$seconds வினாடிகள் முன் அனுப்பப்பட்டது';
  }

  @override
  String get waitingForGps => 'GPS-க்காகக் காத்திருக்கிறது…';

  @override
  String get noSignal =>
      'சிக்னல் இல்லை. இணையம் திரும்பியதும் இருப்பிடம் அனுப்பப்படும்.';

  @override
  String nextStopName(String name) {
    return 'அடுத்த நிறுத்தம்: $name';
  }

  @override
  String stopsReached(int reached, int total) {
    return '$total நிறுத்தங்களில் $reached கடந்தது';
  }

  @override
  String get lastStopReached =>
      'எல்லா நிறுத்தங்களும் முடிந்தன. பயணத்தை முடி என்பதைத் தட்டவும்.';

  @override
  String get mockLocationWarning =>
      'போலி GPS கண்டறியப்பட்டது. போலி இருப்பிடச் செயலியை அணைக்கவும். பேருந்தின் இருப்பிடம் அனுப்பப்படவில்லை.';

  @override
  String get problemLocationOff =>
      'இருப்பிடம் அணைக்கப்பட்டுள்ளது. பயணத்தைத் தொடங்க அதை இயக்கவும்.';

  @override
  String get problemPermissionDenied =>
      'பேருந்தின் இருப்பிடத்தைப் பகிர இந்தச் செயலிக்கு இருப்பிட அனுமதி தேவை.';

  @override
  String get problemPermissionDeniedForever =>
      'இருப்பிட அனுமதி தடுக்கப்பட்டுள்ளது. அமைப்புகளில் அனுமதிக்கவும்.';

  @override
  String get problemStartFailed =>
      'பயணத்தைத் தொடங்க முடியவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String get openSettings => 'அமைப்புகளைத் திற';

  @override
  String agoSeconds(int seconds) {
    return '$seconds வினாடிகள் முன்';
  }

  @override
  String agoMinutes(int minutes) {
    return '$minutes நிமிடங்கள் முன்';
  }

  @override
  String busLive(String ago) {
    return 'நேரலை · $ago புதுப்பிக்கப்பட்டது';
  }

  @override
  String busStale(String ago) {
    return 'சிக்னல் குறைவு · கடைசி இருப்பிடம் $ago';
  }

  @override
  String busOffline(String time) {
    return 'இணைப்பில் இல்லை · கடைசியாக $time மணிக்குத் தெரிந்தது';
  }

  @override
  String get busNotRunning => 'பேருந்து இப்போது இயங்கவில்லை.';

  @override
  String get noBusOnRoute =>
      'இந்த வழித்தடத்துக்கு இன்னும் பேருந்து ஒதுக்கப்படவில்லை.';

  @override
  String get followBus => 'பேருந்தைப் பின்தொடர்';

  @override
  String get allBusesTitle => 'எல்லாப் பேருந்துகளும்';

  @override
  String get allBusesEmpty => 'இப்போது எந்தப் பேருந்தும் இயங்கவில்லை.';

  @override
  String get mapAttribution => '© OpenStreetMap பங்களிப்பாளர்கள்';

  @override
  String etaMinutes(int minutes) {
    return '$minutes நிமிடங்களில் வரும்';
  }

  @override
  String etaAround(String time) {
    return 'சுமார் $time';
  }

  @override
  String get arrivingNow => 'பேருந்து இப்போது உங்கள் நிறுத்தத்தில் உள்ளது';

  @override
  String passedAt(String time) {
    return '$time மணிக்கு உங்கள் நிறுத்தத்தைக் கடந்தது';
  }

  @override
  String get passedNoTime => 'பேருந்து உங்கள் நிறுத்தத்தைக் கடந்துவிட்டது';

  @override
  String get offRoute =>
      'பேருந்து வழக்கமான வழித்தடத்தில் இல்லை, அதனால் வருகை நேரத்தைக் கணிக்க முடியவில்லை.';

  @override
  String get etaFromLastPosition =>
      'கடைசியாகத் தெரிந்த இருப்பிடத்தின் அடிப்படையில் கணிக்கப்பட்டது';

  @override
  String get fullRouteTitle => 'முழு வழித்தடம்';

  @override
  String get fullRouteButton => 'எல்லா நிறுத்தங்களையும் பார்';

  @override
  String stopScheduled(String time) {
    return 'அட்டவணை நேரம் $time';
  }

  @override
  String stopPassedAt(String time) {
    return '$time மணிக்குக் கடந்தது';
  }

  @override
  String get stopPassed => 'கடந்தது';

  @override
  String stopExpected(String time) {
    return 'எதிர்பார்ப்பு $time';
  }

  @override
  String get busIsHere => 'பேருந்து இங்கே';

  @override
  String get alertsTitle => 'அறிவிப்புகள்';

  @override
  String get alertsEmpty =>
      'இப்போது அறிவிப்புகள் இல்லை. கடந்த ஒரு நாளின் பயணச் செய்திகளும் கடந்த வாரத்தின் அறிவிப்புகளும் இங்கே தெரியும்.';

  @override
  String alertTripStarted(String bus) {
    return '$bus பயணத்தைத் தொடங்கியது.';
  }

  @override
  String alertDelay(String bus, int minutes) {
    return '$bus சுமார் $minutes நிமிடங்கள் தாமதமாக ஓடுகிறது.';
  }

  @override
  String alertLate(String bus) {
    return '$bus தாமதமாக வரும் என ஓட்டுநர் தெரிவித்துள்ளார்.';
  }

  @override
  String alertBreakdown(String bus) {
    return '$bus பழுதடைந்துள்ளது. போக்குவரத்து அலுவலகத்தின் அறிவிப்புக்குக் காத்திருக்கவும்.';
  }

  @override
  String get announcementLabel => 'போக்குவரத்து அலுவலகம்';

  @override
  String get notificationSettingsTitle => 'அறிவிப்பு அமைப்புகள்';

  @override
  String get settingApproaching => 'பேருந்து என் நிறுத்தத்தை நெருங்கும்போது';

  @override
  String get settingLeadStops => 'எப்போது தெரிவிக்க வேண்டும்';

  @override
  String leadStopsOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நிறுத்தங்கள் முன்',
      one: '1 நிறுத்தம் முன்',
    );
    return '$_temp0';
  }

  @override
  String get settingTripStarted => 'பேருந்து புறப்பட்டதும்';

  @override
  String get settingDelays => 'தாமதம் மற்றும் பழுது';

  @override
  String get settingAnnouncements => 'போக்குவரத்து அலுவலக அறிவிப்புகள்';

  @override
  String get settingQuietDays => 'அமைதி நாட்கள்';

  @override
  String get settingQuietDaysHelp =>
      'இந்த நாட்களில் பழுது தவிர வேறு அறிவிப்புகள் வராது.';

  @override
  String get settingsSaveFailed =>
      'சேமிக்க முடியவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயலவும்.';

  @override
  String get driverReportLate => 'தாமதம்';

  @override
  String get driverReportBreakdown => 'பழுது';

  @override
  String get driverReportSent => 'பயணிகளுக்குத் தெரிவிக்கப்பட்டது.';

  @override
  String get breakdownConfirmTitle => 'பழுதைத் தெரிவிக்கவா?';

  @override
  String get breakdownConfirmBody =>
      'இந்த வழித்தடத்தில் உள்ள எல்லாப் பயணிகளுக்கும் பேருந்து பழுதடைந்ததாகத் தெரிவிக்கப்படும்.';

  @override
  String get reportButton => 'தெரிவி';

  @override
  String get myPassTitle => 'என் பேருந்து அனுமதிச்சீட்டு';

  @override
  String get passShowDriver => 'ஏறும்போது இதை ஓட்டுநரிடம் காட்டவும்.';

  @override
  String passValidUntil(String date) {
    return '$date வரை செல்லும்';
  }

  @override
  String get passExpired =>
      'உங்கள் அனுமதிச்சீட்டு காலாவதியாகிவிட்டது. போக்குவரத்து அலுவலகத்தைத் தொடர்புகொள்ளவும்.';

  @override
  String get passNone =>
      'உங்கள் கணக்கில் பேருந்து அனுமதிச்சீட்டு இல்லை. போக்குவரத்து அலுவலகத்தைத் தொடர்புகொள்ளவும்.';

  @override
  String get passPreparing => 'உங்கள் அனுமதிச்சீட்டு தயாராகிறது…';

  @override
  String passRefreshesIn(int seconds) {
    return '$seconds வினாடிகளில் மாறும்; திரைப்பிடிப்புகள் செல்லாது';
  }

  @override
  String get scanPassButton => 'அனுமதிச்சீட்டை ஸ்கேன் செய்';

  @override
  String get scanTitle => 'அனுமதிச்சீட்டுகளை ஸ்கேன் செய்';

  @override
  String get scanHint => 'மாணவரின் QR குறியீட்டை நோக்கி கேமராவைக் காட்டவும்.';

  @override
  String boardedCount(int count) {
    return '$count பேர் ஏறினர்';
  }

  @override
  String scanBoarded(String name) {
    return '$name – ஏறினார்';
  }

  @override
  String scanAlreadyBoarded(String name) {
    return '$name ஏற்கனவே ஏறிவிட்டார்';
  }

  @override
  String get scanNotAPass => 'இது பேருந்து அனுமதிச்சீட்டு அல்ல.';

  @override
  String get scanInvalid => 'இந்த அனுமதிச்சீட்டு உண்மையானது அல்ல.';

  @override
  String get scanExpiredCode =>
      'பழைய குறியீடு. அனுமதிச்சீட்டை மீண்டும் திறக்க மாணவரிடம் சொல்லவும்.';

  @override
  String scanNoPass(String name) {
    return '$name அவர்களிடம் பேருந்து அனுமதிச்சீட்டு இல்லை.';
  }

  @override
  String scanPassExpired(String name) {
    return '$name அவர்களின் அனுமதிச்சீட்டு காலாவதியானது.';
  }

  @override
  String scanWrongRoute(String name) {
    return '$name இந்தப் பேருந்தில் பயணிக்க அனுமதி இல்லை.';
  }

  @override
  String get scanOffline =>
      'இணைப்பு இல்லை. இப்போதைக்கு அனுமதிச்சீட்டைப் பார்த்துச் சரிபார்க்கவும்.';

  @override
  String get missedBusButton => 'பேருந்தைத் தவறவிட்டீர்களா?';

  @override
  String get missedBusTitle => 'வேறு பேருந்தில் செல்லுங்கள்';

  @override
  String get missedBusIntro =>
      'போக்குவரத்து அலுவலகம் உங்களுக்கு அனுமதித்த கல்லூரிப் பேருந்துகள், நேரத்தில் அடையக்கூடிய அருகிலுள்ள நிறுத்தத்துடன்.';

  @override
  String get missedBusFromHere =>
      'நீங்கள் இப்போது இருக்கும் இடத்திலிருந்து தூரம்.';

  @override
  String missedBusFromStop(String stop) {
    return 'உங்கள் நிறுத்தமான $stop இலிருந்து தூரம். இன்னும் அருகிலுள்ள நிறுத்தத்திற்கு இருப்பிட அனுமதி தரவும்.';
  }

  @override
  String get missedBusLocating => 'நீங்கள் இருக்கும் இடத்தைக் கண்டறிகிறது…';

  @override
  String get missedBusNone =>
      'இப்போது வேறு எந்தக் கல்லூரிப் பேருந்தும் உங்களை ஏற்ற முடியாது.';

  @override
  String get missedBusNoneHint =>
      'உங்கள் வழித்தடத்திற்கு அலுவலகம் அனுமதித்த, இன்னும் உங்கள் அருகிலுள்ள நிறுத்தத்திற்கு வரவுள்ள பேருந்துகள் மட்டுமே இங்கே காட்டப்படும்.';

  @override
  String get missedBusNeedsPass =>
      'வேறு கல்லூரிப் பேருந்தில் செல்ல செல்லுபடியாகும் அனுமதிச்சீட்டு தேவை.';

  @override
  String missedBusGetOnAt(String stop) {
    return '$stop இல் ஏறவும்';
  }

  @override
  String missedBusWalk(String distance, int minutes) {
    return '$distance நடை, சுமார் $minutes நிமிடம்';
  }

  @override
  String missedBusBusIn(int minutes, String time) {
    return 'பேருந்து $minutes நிமிடத்தில், சுமார் $time மணிக்கு வரும்';
  }

  @override
  String get missedBusBusThereNow =>
      'பேருந்து இப்போது அந்த நிறுத்தத்தில் உள்ளது';

  @override
  String get missedBusTooFar => 'உங்களுக்கு முன் பேருந்து அங்கு சென்றுவிடலாம்.';

  @override
  String missedBusSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'மற்ற வழித்தடங்களுக்கு $count இருக்கைகள்',
      one: 'மற்ற வழித்தடங்களுக்கு 1 இருக்கை',
    );
    return '$_temp0';
  }

  @override
  String get missedBusFull => 'மற்ற வழித்தடங்களுக்கு இருக்கை இல்லை';

  @override
  String distanceMetres(int metres) {
    return '$metres மீ';
  }

  @override
  String distanceKm(String km) {
    return '$km கி.மீ';
  }

  @override
  String get holdSeatButton => 'இருக்கையை ஒதுக்கு';

  @override
  String holdHeld(String stop) {
    return 'இருக்கை ஒதுக்கப்பட்டது. $stop இல் இருந்து ஓட்டுநரிடம் உங்கள் அனுமதிச்சீட்டைக் காட்டுங்கள்.';
  }

  @override
  String get holdCancelButton => 'இருக்கையை விடு';

  @override
  String get holdBoarded => 'நீங்கள் இந்தப் பேருந்தில் ஏறிவிட்டீர்கள்.';

  @override
  String holdMissed(String stop) {
    return 'பேருந்து $stop ஐக் கடந்துவிட்டதால் உங்கள் இருக்கை விடுவிக்கப்பட்டது.';
  }

  @override
  String get holdFull => 'மன்னிக்கவும், கடைசி இருக்கையும் இப்போது போய்விட்டது.';

  @override
  String get holdPassed => 'பேருந்து அந்த நிறுத்தத்தைக் கடந்துவிட்டது.';

  @override
  String get holdNotAllowed =>
      'இந்தப் பேருந்து உங்கள் வழித்தட மாணவர்களை ஏற்றாது.';

  @override
  String get holdNotRunning => 'இந்தப் பேருந்து இப்போது இயங்கவில்லை.';

  @override
  String get holdOffline => 'இணைப்பு இல்லை. மீண்டும் முயலவும்.';

  @override
  String get waitingRidersTitle => 'மற்ற வழித்தடப் பயணிகள்';

  @override
  String waitingRider(String name, String stop) {
    return '$name — $stop';
  }

  @override
  String scanNoSeatHeld(String name) {
    return '$name இந்தப் பேருந்தில் இருக்கை ஒதுக்கவில்லை. செயலியில் ஒதுக்கலாம்.';
  }

  @override
  String get eveningSeatsTitle => 'மாலை இருக்கைகள்';

  @override
  String get eveningSeatsButton => 'மாலை இருக்கைகள்';

  @override
  String get eveningIntro =>
      'இன்று மாலை அல்லது நாளை வளாகத்திலிருந்து புறப்படும் கல்லூரிப் பேருந்தில் காலியான இருக்கையை முன்பதிவு செய்யுங்கள். வழித்தட அனுமதிச்சீட்டு வைத்திருப்பவர்களின் இருக்கைகள் எப்போதும் அவர்களுக்கே.';

  @override
  String get eveningToday => 'இன்று';

  @override
  String get eveningTomorrow => 'நாளை';

  @override
  String get eveningNone =>
      'முன்பதிவு செய்ய இன்னும் மாலைப் பேருந்துகள் இல்லை. முன்பதிவு முந்தைய நாள் மாலை திறக்கும்.';

  @override
  String eveningLeaves(String time) {
    return 'வளாகத்திலிருந்து $time மணிக்குப் புறப்படும்';
  }

  @override
  String fareRupees(String fare) {
    return '₹$fare';
  }

  @override
  String seatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count இருக்கைகள் உள்ளன',
      one: '1 இருக்கை உள்ளது',
      zero: 'இருக்கை இல்லை',
    );
    return '$_temp0';
  }

  @override
  String bookingOpensAt(String time) {
    return 'முன்பதிவு $time மணிக்குத் திறக்கும்';
  }

  @override
  String bookingUntil(String time) {
    return '$time மணி வரை முன்பதிவு செய்யலாம்';
  }

  @override
  String get passCoversBus =>
      'உங்கள் அனுமதிச்சீட்டு இந்தப் பேருந்துக்குச் செல்லும்.';

  @override
  String get bookSeatButton => 'இருக்கையை முன்பதிவு செய்';

  @override
  String get bookedLabel => 'இந்தப் பேருந்தில் உங்களுக்கு இருக்கை உள்ளது';

  @override
  String get chooseDropTitle => 'எங்கே இறங்குவீர்கள்?';

  @override
  String bookForButton(String fare) {
    return '₹$fareக்கு முன்பதிவு செய்';
  }

  @override
  String get bookAlready =>
      'இந்தப் பேருந்தில் ஏற்கனவே உங்களுக்கு இருக்கை உள்ளது.';

  @override
  String get bookFull => 'மன்னிக்கவும், இருக்கைகள் இல்லை.';

  @override
  String get bookNotOpen => 'முன்பதிவு இன்னும் திறக்கவில்லை.';

  @override
  String get bookClosed => 'முன்பதிவு முடிந்தது';

  @override
  String get bookNoGuestSeats =>
      'இந்த வழித்தடத்தில் முன்பதிவுக்கு இருக்கைகள் இல்லை.';

  @override
  String get bookBadStop => 'வேறு நிறுத்தத்தைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get bookPaymentsUnavailable =>
      'இப்போது பணம் செலுத்த முடியாது. பின்னர் முயலவும்.';

  @override
  String get bookOffline => 'இணைப்பு இல்லை. மீண்டும் முயலவும்.';

  @override
  String get paymentCancelled =>
      'பணம் செலுத்துவது ரத்தானதால் இருக்கை விடுவிக்கப்பட்டது.';

  @override
  String get paymentExpired =>
      'பணம் செலுத்த நேரம் கடந்ததால் இருக்கை விடுவிக்கப்பட்டது. மீண்டும் முன்பதிவு செய்யவும்.';

  @override
  String get paymentInvalid =>
      'பணம் செலுத்தியதை உறுதிசெய்ய முடியவில்லை. பணம் எடுக்கப்பட்டிருந்தால் போக்குவரத்து அலுவலகத்தைத் தொடர்புகொள்ளவும்.';

  @override
  String get demoPaymentTitle => 'சோதனைப் பணம்';

  @override
  String get demoPaymentBody =>
      'பணம் எதுவும் எடுக்கப்படாது. சோதனையின்போது இது Razorpay-க்குப் பதிலாகச் செயல்படுகிறது.';

  @override
  String payButton(String amount) {
    return '₹$amount செலுத்து';
  }

  @override
  String get ticketsTitle => 'உங்கள் பயணச்சீட்டுகள்';

  @override
  String get ticketShow =>
      'இதை ஓட்டுநரிடம் காட்டுங்கள். ஒருமுறை மட்டுமே செல்லும்.';

  @override
  String get ticketQrLabel => 'பேருந்துப் பயணச்சீட்டு';

  @override
  String get ticketUsed => 'பயன்படுத்தப்பட்டது';

  @override
  String ticketGetOff(String stop) {
    return '$stop இல் இறங்கவும்';
  }

  @override
  String pendingUntil(String time) {
    return 'பணம் செலுத்தக் காத்திருக்கிறது. இருக்கை $time வரை வைக்கப்படும்.';
  }

  @override
  String get cancelBookingButton => 'முன்பதிவை ரத்து செய்';

  @override
  String get noDailyBusTitle => 'நான் தினமும் கல்லூரிப் பேருந்தில் செல்வதில்லை';

  @override
  String get noDailyBusSubtitle =>
      'விடுதி மாணவர்கள், சொந்த வாகனம் உள்ளவர்கள்: தேவைப்படும்போது மாலை இருக்கையை முன்பதிவு செய்யுங்கள்.';

  @override
  String get noDailyBusHome =>
      'உங்களுக்குத் தினசரி கல்லூரிப் பேருந்து இல்லை. வீட்டுக்குச் செல்ல வேண்டும்போது மாலைப் பேருந்தில் காலியான இருக்கையை முன்பதிவு செய்யுங்கள்.';

  @override
  String get chooseDailyRouteButton =>
      'நான் தினமும் கல்லூரிப் பேருந்தில் செல்கிறேன்';

  @override
  String get scanTicketUsed => 'இந்தப் பயணச்சீட்டு ஏற்கனவே பயன்படுத்தப்பட்டது.';

  @override
  String scanWrongTrip(String name) {
    return '$name அவர்களின் பயணச்சீட்டு வேறு பேருந்துக்கானது.';
  }

  @override
  String scanNotPaid(String name) {
    return '$name அவர்களின் பயணச்சீட்டுக்குப் பணம் செலுத்தப்படவில்லை.';
  }

  @override
  String leaveBy(String time) {
    return '$time மணிக்குள் வீட்டிலிருந்து புறப்படுங்கள்';
  }

  @override
  String get leaveNow => 'பேருந்தைப் பிடிக்க இப்போதே புறப்படுங்கள்';

  @override
  String usualDelayLate(int minutes, String day) {
    return '$dayகளில் பொதுவாகச் சுமார் $minutes நிமிடம் தாமதம்';
  }

  @override
  String usualDelayOnTime(String day) {
    return '$dayகளில் பொதுவாகச் சரியான நேரம்';
  }

  @override
  String get usualDelayTitle => 'வளாகத்தில் வழக்கமான தாமதம்';

  @override
  String usualDelayRow(String day, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'சுமார் $minutes நிமிடம் தாமதம்',
      zero: 'சரியான நேரம்',
    );
    return '$day: $_temp0';
  }

  @override
  String get crowdSeats => 'இருக்கைகள் உள்ளன';

  @override
  String get crowdFew => 'சில இருக்கைகளே உள்ளன';

  @override
  String get crowdStanding => 'நின்றுதான் பயணம்';

  @override
  String get notRidingLabel => 'இன்று மாலை பயணிக்கவில்லை';

  @override
  String notRidingHelp(String time) {
    return 'உங்கள் இருக்கையை வேறு மாணவர் முன்பதிவு செய்யலாம். $time வரை இதை மாற்றலாம்.';
  }

  @override
  String get notRidingLocked =>
      'முன்பதிவு முடிந்ததால் இதை இப்போது மாற்ற முடியாது.';

  @override
  String get notRidingSeatTaken =>
      'உங்கள் இருக்கையை வேறொருவர் முன்பதிவு செய்துவிட்டதால் திரும்பப் பெற முடியாது.';

  @override
  String get settingLeaveHome => 'வீட்டிலிருந்து புறப்படும் நேரம்';

  @override
  String get settingLeaveHomeHelp =>
      'புறப்பட வேண்டிய நேரத்தை அறிய, நிறுத்தத்துக்கு நடக்கும் நேரத்தை அமைக்கவும்.';

  @override
  String get settingWalkMinutes => 'வீட்டிலிருந்து என் நிறுத்தத்துக்கு நடை';

  @override
  String walkMinutesValue(int minutes) {
    return '$minutes நிமிடம்';
  }

  @override
  String get walkMinutesNone => 'அமைக்கவில்லை';

  @override
  String get sosButton => 'SOS';

  @override
  String get sosConfirmTitle => 'SOS அனுப்பவா?';

  @override
  String get sosConfirmBody =>
      'இந்தப் பேருந்தின் எண்ணும் அது இப்போது இருக்கும் இடமும் போக்குவரத்து அலுவலகத்துக்குச் செல்லும். அவசர நேரத்தில் மட்டும் பயன்படுத்தவும்.';

  @override
  String get sosSendButton => 'SOS அனுப்பு';

  @override
  String get sosSent =>
      'SOS அனுப்பப்பட்டது. பேருந்து இருக்கும் இடம் போக்குவரத்து அலுவலகத்துக்குத் தெரியும்.';

  @override
  String get sosNoTrip =>
      'பயணம் எதுவும் நடக்காததால் அனுப்ப பேருந்து இருப்பிடம் இல்லை. போக்குவரத்து அலுவலகத்தை அழைக்கவும்.';

  @override
  String get shareTripButton => 'என் பயணத்தைப் பகிர்';

  @override
  String get shareTripTitle => 'என் பயணத்தைப் பகிர்';

  @override
  String get shareTripBody =>
      'இந்த இணைப்பு உள்ள எவரும் பயணம் முடியும் வரை உங்கள் பேருந்தை வரைபடத்தில் பார்க்கலாம். இது பேருந்தை மட்டுமே காட்டும், உங்களை அல்ல.';

  @override
  String get shareNoTrip =>
      'உங்கள் பேருந்து ஓடவில்லை, அதனால் பகிர பயணம் இல்லை.';

  @override
  String get copyLinkButton => 'இணைப்பை நகலெடு';

  @override
  String get linkCopied => 'இணைப்பு நகலெடுக்கப்பட்டது';

  @override
  String get closeButton => 'மூடு';

  @override
  String get verifyNowTestButton => 'இப்போதே சரிபார் (சோதனை முறை)';

  @override
  String get verifyTestModeNote =>
      'சோதனை முறை: இங்கு மின்னஞ்சல் அனுப்பப்படாது. இந்தக் கணக்கை உடனே சரிபார்க்க கீழே தட்டவும்.';
}
