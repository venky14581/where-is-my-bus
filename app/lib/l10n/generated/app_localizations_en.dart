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

  @override
  String etaMinutes(int minutes) {
    return 'Arrives in $minutes min';
  }

  @override
  String etaAround(String time) {
    return 'around $time';
  }

  @override
  String get arrivingNow => 'The bus is at your stop now';

  @override
  String passedAt(String time) {
    return 'Passed your stop at $time';
  }

  @override
  String get passedNoTime => 'The bus has passed your stop';

  @override
  String get offRoute =>
      'The bus is away from its usual route, so there is no arrival time.';

  @override
  String get etaFromLastPosition => 'Estimated from the last known position';

  @override
  String get fullRouteTitle => 'Full route';

  @override
  String get fullRouteButton => 'See all stops';

  @override
  String stopScheduled(String time) {
    return 'Scheduled $time';
  }

  @override
  String stopPassedAt(String time) {
    return 'Passed at $time';
  }

  @override
  String get stopPassed => 'Passed';

  @override
  String stopExpected(String time) {
    return 'Expected $time';
  }

  @override
  String get busIsHere => 'Bus is here';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsEmpty =>
      'No alerts right now. Trip news from the last day and announcements from the last week appear here.';

  @override
  String alertTripStarted(String bus) {
    return '$bus has started its trip.';
  }

  @override
  String alertDelay(String bus, int minutes) {
    return '$bus is running about $minutes min behind schedule.';
  }

  @override
  String alertLate(String bus) {
    return 'The driver of $bus reports the bus is running late.';
  }

  @override
  String alertBreakdown(String bus) {
    return '$bus has broken down. Watch for news from the transport office.';
  }

  @override
  String get announcementLabel => 'Transport office';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get settingApproaching => 'Bus approaching my stop';

  @override
  String get settingLeadStops => 'Tell me when it is';

  @override
  String leadStopsOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops away',
      one: '1 stop away',
    );
    return '$_temp0';
  }

  @override
  String get settingTripStarted => 'Bus has started';

  @override
  String get settingDelays => 'Delays and breakdowns';

  @override
  String get settingAnnouncements => 'Transport office announcements';

  @override
  String get settingQuietDays => 'Quiet days';

  @override
  String get settingQuietDaysHelp =>
      'No notifications on these days, except breakdowns.';

  @override
  String get settingsSaveFailed =>
      'Couldn\'t save. Check the internet and try again.';

  @override
  String get driverReportLate => 'Running late';

  @override
  String get driverReportBreakdown => 'Breakdown';

  @override
  String get driverReportSent => 'Riders have been told.';

  @override
  String get breakdownConfirmTitle => 'Report a breakdown?';

  @override
  String get breakdownConfirmBody =>
      'Every rider on this route will be told the bus has broken down.';

  @override
  String get reportButton => 'Report';

  @override
  String get myPassTitle => 'My bus pass';

  @override
  String get passShowDriver => 'Show this to the driver when you board.';

  @override
  String passValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get passExpired =>
      'Your pass has expired. Contact the transport office.';

  @override
  String get passNone =>
      'No bus pass on your account. Contact the transport office.';

  @override
  String get passPreparing => 'Preparing your pass…';

  @override
  String passRefreshesIn(int seconds) {
    return 'Changes in $seconds s, so screenshots stop working';
  }

  @override
  String get scanPassButton => 'Scan pass';

  @override
  String get scanTitle => 'Scan passes';

  @override
  String get scanHint => 'Point the camera at the student\'s QR code.';

  @override
  String boardedCount(int count) {
    return '$count boarded';
  }

  @override
  String scanBoarded(String name) {
    return '$name – boarded';
  }

  @override
  String scanAlreadyBoarded(String name) {
    return '$name already boarded';
  }

  @override
  String get scanNotAPass => 'That\'s not a bus pass.';

  @override
  String get scanInvalid => 'This pass is not genuine.';

  @override
  String get scanExpiredCode =>
      'Old code. Ask the student to open their pass again.';

  @override
  String scanNoPass(String name) {
    return '$name has no bus pass.';
  }

  @override
  String scanPassExpired(String name) {
    return '$name\'s pass has expired.';
  }

  @override
  String scanWrongRoute(String name) {
    return '$name is not allowed on this bus.';
  }

  @override
  String get scanOffline => 'No connection. Check the pass by eye for now.';

  @override
  String get missedBusButton => 'Missed your bus?';

  @override
  String get missedBusTitle => 'Catch another bus';

  @override
  String get missedBusIntro =>
      'College buses the transport office allows you to ride, each with the nearest stop you can reach in time.';

  @override
  String get missedBusFromHere => 'Distances from where you are now.';

  @override
  String missedBusFromStop(String stop) {
    return 'Distances from your stop, $stop. Allow location to get a closer match.';
  }

  @override
  String get missedBusLocating => 'Finding where you are…';

  @override
  String get missedBusNone => 'No other college bus can take you right now.';

  @override
  String get missedBusNoneHint =>
      'Only buses the transport office allows for your route, still on their way to a stop near you, are shown here.';

  @override
  String get missedBusNeedsPass =>
      'You need a valid bus pass to ride another college bus.';

  @override
  String missedBusGetOnAt(String stop) {
    return 'Get on at $stop';
  }

  @override
  String missedBusWalk(String distance, int minutes) {
    return '$distance walk, about $minutes min';
  }

  @override
  String missedBusBusIn(int minutes, String time) {
    return 'Bus there in $minutes min, around $time';
  }

  @override
  String get missedBusBusThereNow => 'The bus is at that stop now';

  @override
  String get missedBusTooFar => 'The bus may get there before you.';

  @override
  String missedBusSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats for other routes',
      one: '1 seat for other routes',
    );
    return '$_temp0';
  }

  @override
  String get missedBusFull => 'No seats left for other routes';

  @override
  String distanceMetres(int metres) {
    return '$metres m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get holdSeatButton => 'Hold a seat';

  @override
  String holdHeld(String stop) {
    return 'Seat held. Be at $stop and show your pass to the driver.';
  }

  @override
  String get holdCancelButton => 'Give up seat';

  @override
  String get holdBoarded => 'You boarded this bus.';

  @override
  String holdMissed(String stop) {
    return 'The bus left $stop, so your seat was released.';
  }

  @override
  String get holdFull => 'Sorry, the last seat has just gone.';

  @override
  String get holdPassed => 'The bus has already passed that stop.';

  @override
  String get holdNotAllowed => 'This bus does not take riders from your route.';

  @override
  String get holdNotRunning => 'This bus is no longer running.';

  @override
  String get holdOffline => 'No connection. Try again.';

  @override
  String get waitingRidersTitle => 'Riders from other routes';

  @override
  String waitingRider(String name, String stop) {
    return '$name at $stop';
  }

  @override
  String scanNoSeatHeld(String name) {
    return '$name has no seat held on this bus. They can hold one in the app.';
  }

  @override
  String get eveningSeatsTitle => 'Evening seats';

  @override
  String get eveningSeatsButton => 'Evening seats';

  @override
  String get eveningIntro =>
      'Book a spare seat on a college bus leaving campus this evening or tomorrow. A route\'s pass holders always keep their seats.';

  @override
  String get eveningToday => 'Today';

  @override
  String get eveningTomorrow => 'Tomorrow';

  @override
  String get eveningNone =>
      'No evening buses to book yet. Booking opens the evening before.';

  @override
  String eveningLeaves(String time) {
    return 'Leaves campus at $time';
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
      other: '$count seats left',
      one: '1 seat left',
      zero: 'No seats left',
    );
    return '$_temp0';
  }

  @override
  String bookingOpensAt(String time) {
    return 'Booking opens at $time';
  }

  @override
  String bookingUntil(String time) {
    return 'Book until $time';
  }

  @override
  String get passCoversBus => 'Your bus pass covers this bus.';

  @override
  String get bookSeatButton => 'Book a seat';

  @override
  String get bookedLabel => 'You have a seat on this bus';

  @override
  String get chooseDropTitle => 'Where do you get off?';

  @override
  String bookForButton(String fare) {
    return 'Book for ₹$fare';
  }

  @override
  String get bookAlready => 'You already have a seat on this bus.';

  @override
  String get bookFull => 'Sorry, no seats are left.';

  @override
  String get bookNotOpen => 'Booking is not open yet.';

  @override
  String get bookClosed => 'Booking has closed';

  @override
  String get bookNoGuestSeats => 'This route has no seats to book.';

  @override
  String get bookBadStop => 'Choose another stop.';

  @override
  String get bookPaymentsUnavailable =>
      'Payment is not available right now. Try again later.';

  @override
  String get bookOffline => 'No connection. Try again.';

  @override
  String get paymentCancelled => 'Payment cancelled, so the seat was released.';

  @override
  String get paymentExpired =>
      'Payment took too long, so the seat was released. Book again.';

  @override
  String get paymentInvalid =>
      'The payment could not be confirmed. If money was taken, contact the transport office.';

  @override
  String get demoPaymentTitle => 'Demo payment';

  @override
  String get demoPaymentBody =>
      'No money is taken. This stands in for Razorpay while testing.';

  @override
  String payButton(String amount) {
    return 'Pay ₹$amount';
  }

  @override
  String get ticketsTitle => 'Your tickets';

  @override
  String get ticketShow => 'Show this to the driver. It works for one scan.';

  @override
  String get ticketQrLabel => 'Bus ticket';

  @override
  String get ticketUsed => 'Used';

  @override
  String ticketGetOff(String stop) {
    return 'Get off at $stop';
  }

  @override
  String pendingUntil(String time) {
    return 'Waiting for payment. The seat is kept until $time.';
  }

  @override
  String get cancelBookingButton => 'Cancel booking';

  @override
  String get noDailyBusTitle => 'I don\'t take a college bus every day';

  @override
  String get noDailyBusSubtitle =>
      'Hostellers and own transport: book an evening seat when you need one.';

  @override
  String get noDailyBusHome =>
      'You have no daily college bus. When you need a ride home, book a spare evening seat.';

  @override
  String get chooseDailyRouteButton => 'I take a college bus every day';

  @override
  String get scanTicketUsed => 'This ticket has already been used.';

  @override
  String scanWrongTrip(String name) {
    return '$name\'s ticket is for another bus.';
  }

  @override
  String scanNotPaid(String name) {
    return '$name\'s ticket is not paid.';
  }

  @override
  String leaveBy(String time) {
    return 'Leave home by $time';
  }

  @override
  String get leaveNow => 'Leave now to catch it';

  @override
  String usualDelayLate(int minutes, String day) {
    return 'Usually about $minutes min late on ${day}s';
  }

  @override
  String usualDelayOnTime(String day) {
    return 'Usually on time on ${day}s';
  }

  @override
  String get usualDelayTitle => 'Usual delay at campus';

  @override
  String usualDelayRow(String day, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'about $minutes min late',
      zero: 'on time',
    );
    return '$day: $_temp0';
  }

  @override
  String get crowdSeats => 'Seats available';

  @override
  String get crowdFew => 'Few seats left';

  @override
  String get crowdStanding => 'Standing only';

  @override
  String get notRidingLabel => 'Not riding this evening';

  @override
  String notRidingHelp(String time) {
    return 'Another student can book your seat. You can change this until $time.';
  }

  @override
  String get notRidingLocked =>
      'Booking has closed, so this cannot change now.';

  @override
  String get notRidingSeatTaken =>
      'Your seat has been booked by someone else, so it cannot be taken back.';

  @override
  String get settingLeaveHome => 'Time to leave home';

  @override
  String get settingLeaveHomeHelp =>
      'Set your walk to the stop to be told when to leave.';

  @override
  String get settingWalkMinutes => 'Walk from home to my stop';

  @override
  String walkMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String get walkMinutesNone => 'Not set';
}
