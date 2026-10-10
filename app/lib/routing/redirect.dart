import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/app_user.dart';
import '../features/auth/domain/credentials.dart';
import '../features/auth/domain/session.dart';
import 'routes.dart';

/// Where [location] should go for this [session], or null to stay.
///
/// This is the only place that decides which screens a role can see, so a
/// student can never land on a driver screen and the other way round. The
/// security rules enforce the same split on the server.
String? redirectFor(AsyncValue<Session> session, String location) {
  final current = session.value;
  if (current == null) {
    // Still starting up, or the first load failed. The splash screen shows
    // a retry button for the error case.
    return _goTo(Routes.splash, location);
  }

  switch (current) {
    case SignedOut():
      return Routes.public.contains(location) ? null : Routes.welcome;

    case SignedIn(profile: null, :final email):
      // Sign-up creates the account before the profile, so stay put while
      // the sign-up screen finishes writing it.
      if (location == Routes.studentSignUp) return null;
      return _goTo(
        isCollegeStudentEmail(email) ? Routes.studentFinishSetup : Routes.accountProblem,
        location,
      );

    case SignedIn(:final profile?, :final emailVerified):
      switch (profile.role) {
        case UserRole.student:
          if (!emailVerified) return _goTo(Routes.studentVerifyEmail, location);
          // Route and stop are picked once, before anything else.
          if (profile.routeId == null) return _goTo(Routes.studentChooseRoute, location);
          final inStudentApp = Routes.isUnder(location, Routes.studentHome) &&
              !Routes.studentOnboarding.contains(location);
          return inStudentApp ? null : Routes.studentHome;

        case UserRole.driver:
          if (profile.language == null) return _goTo(Routes.driverLanguage, location);
          // Later language changes go through the app bar menu, so the
          // first-login picker is only for drivers who haven't chosen yet.
          final inDriverApp = Routes.isUnder(location, Routes.driverHome) &&
              location != Routes.driverSignIn &&
              location != Routes.driverLanguage;
          return inDriverApp ? null : Routes.driverHome;

        case UserRole.office:
          return _goTo(Routes.accountProblem, location);
      }
  }
}

String? _goTo(String target, String location) => location == target ? null : target;
