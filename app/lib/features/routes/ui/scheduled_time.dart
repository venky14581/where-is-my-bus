import 'package:flutter/material.dart';

/// Formats an office-entered `HH:mm` time in the reader's locale, for
/// example "7:05 AM" or "காலை 7:05". Falls back to the raw text if malformed.
String formatScheduledTime(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
  final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (hour == null || minute == null || hour > 23 || minute > 59) return hhmm;
  return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
}
