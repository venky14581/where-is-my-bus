import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/ui/alerts_screen.dart';
import '../features/alerts/ui/notification_settings_screen.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/ui/account_problem_screen.dart';
import '../features/auth/ui/driver_language_screen.dart';
import '../features/auth/ui/driver_sign_in_screen.dart';
import '../features/auth/ui/finish_setup_screen.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/auth/ui/student_sign_in_screen.dart';
import '../features/auth/ui/student_sign_up_screen.dart';
import '../features/auth/ui/verify_email_screen.dart';
import '../features/auth/ui/welcome_screen.dart';
import '../features/driver/driver_home_screen.dart';
import '../features/eta/ui/full_route_screen.dart';
import '../features/live/ui/all_buses_screen.dart';
import '../features/booking/ui/evening_seats_screen.dart';
import '../features/missed_bus/ui/missed_bus_screen.dart';
import '../features/pass/ui/pass_screen.dart';
import '../features/pass/ui/scan_screen.dart';
import '../features/routes/ui/choose_route_screen.dart';
import '../features/student/student_home_screen.dart';
import 'redirect.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the session changes.
  final session = ValueNotifier<AsyncValue<Session>>(const AsyncLoading());
  ref.listen(sessionProvider, (_, next) => session.value = next, fireImmediately: true);

  GoRoute route(String path, Widget screen) => GoRoute(path: path, builder: (_, _) => screen);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (_, state) => redirectFor(session.value, state.matchedLocation),
    routes: [
      route(Routes.splash, const SplashScreen()),
      route(Routes.welcome, const WelcomeScreen()),
      route(Routes.accountProblem, const AccountProblemScreen()),
      route(Routes.studentSignIn, const StudentSignInScreen()),
      route(Routes.studentSignUp, const StudentSignUpScreen()),
      route(Routes.studentForgotPassword, const ForgotPasswordScreen()),
      route(Routes.studentVerifyEmail, const VerifyEmailScreen()),
      route(Routes.studentFinishSetup, const FinishSetupScreen()),
      route(Routes.studentHome, const StudentHomeScreen()),
      route(Routes.studentChooseRoute, const ChooseRouteScreen()),
      route(Routes.studentAllBuses, const AllBusesScreen()),
      route(Routes.studentFullRoute, const FullRouteScreen()),
      route(Routes.studentAlerts, const AlertsScreen()),
      route(Routes.studentNotificationSettings, const NotificationSettingsScreen()),
      route(Routes.studentPass, const PassScreen()),
      route(Routes.studentMissedBus, const MissedBusScreen()),
      route(Routes.studentEveningSeats, const EveningSeatsScreen()),
      route(Routes.driverSignIn, const DriverSignInScreen()),
      route(Routes.driverLanguage, const DriverLanguageScreen()),
      route(Routes.driverHome, const DriverHomeScreen()),
      route(Routes.driverScan, const ScanScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
