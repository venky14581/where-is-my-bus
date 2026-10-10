import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/l10n.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import 'auth_failure_message.dart';

/// Busy flag and inline error for a screen that submits one auth action.
mixin AuthSubmit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? error;

  /// Set for driver screens so a wrong PIN reads "Driver ID or PIN is wrong".
  bool get isDriverScreen => false;

  /// Returns true when [action] completed without an [AuthFailure].
  Future<bool> submit(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      return true;
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() => error = authFailureMessage(context.l10n, failure, driver: isDriverScreen));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

abstract final class Validators {
  static FormFieldValidator<String> required(AppLocalizations l10n) =>
      (value) => (value == null || value.trim().isEmpty) ? l10n.errorRequired : null;

  static FormFieldValidator<String> collegeEmail(AppLocalizations l10n) => (value) {
        if (value == null || value.trim().isEmpty) return l10n.errorRequired;
        if (!isCollegeStudentEmail(value)) {
          return l10n.errorNotCollegeEmail(AppConfig.studentEmailDomains.first);
        }
        return null;
      };

  static FormFieldValidator<String> newPassword(AppLocalizations l10n) => (value) {
        if (value == null || value.isEmpty) return l10n.errorRequired;
        if (value.length < AppConfig.minStudentPasswordLength) {
          return l10n.errorPasswordTooShort(AppConfig.minStudentPasswordLength);
        }
        return null;
      };

  static FormFieldValidator<String> driverId(AppLocalizations l10n) => (value) {
        if (value == null || value.trim().isEmpty) return l10n.errorRequired;
        return isValidDriverId(value) ? null : l10n.errorInvalidDriverId;
      };

  static FormFieldValidator<String> pin(AppLocalizations l10n) => (value) {
        if (value == null || value.isEmpty) return l10n.errorRequired;
        return isValidPin(value) ? null : l10n.errorInvalidPin(AppConfig.driverPinLength);
      };
}
