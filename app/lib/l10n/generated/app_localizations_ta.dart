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
  String get routeNotChosenTitle => 'இன்னும் வழித்தடம் தேர்வு செய்யப்படவில்லை';

  @override
  String get routeNotChosenBody =>
      'உங்கள் நகரம், வழித்தடம், நிறுத்தம் ஆகியவற்றை இங்கே தேர்வு செய்வீர்கள். அதன் பிறகு செயலி ஒவ்வொரு முறையும் உங்கள் பேருந்தையே காட்டும்.';

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
}
