import '../../../core/config.dart';
import '../../../core/l10n.dart';
import '../domain/auth_failure.dart';

String authFailureMessage(AppLocalizations l10n, AuthFailure failure, {bool driver = false}) {
  return switch (failure.code) {
    AuthFailureCode.notCollegeEmail =>
      l10n.errorNotCollegeEmail(AppConfig.studentEmailDomains.first),
    AuthFailureCode.invalidDriverId => l10n.errorInvalidDriverId,
    AuthFailureCode.invalidPin => l10n.errorInvalidPin(AppConfig.driverPinLength),
    AuthFailureCode.wrongCredentials =>
      driver ? l10n.errorWrongDriverCredentials : l10n.errorWrongStudentCredentials,
    AuthFailureCode.emailInUse => l10n.errorEmailInUse,
    AuthFailureCode.weakPassword => l10n.errorWeakPassword,
    AuthFailureCode.tooManyAttempts => l10n.errorTooManyAttempts,
    AuthFailureCode.network => l10n.errorNetwork,
    AuthFailureCode.accountDisabled => l10n.errorAccountDisabled,
    AuthFailureCode.unknown => l10n.errorUnknown,
  };
}
