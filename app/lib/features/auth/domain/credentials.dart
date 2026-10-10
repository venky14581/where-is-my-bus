import '../../../core/config.dart';

final _emailPattern = RegExp(r'^[a-z0-9._%+-]+@([a-z0-9-]+(\.[a-z0-9-]+)+)$');
final _driverIdPattern = RegExp(r'^[A-Z0-9-]{3,16}$');

String normalizeEmail(String raw) => raw.trim().toLowerCase();

bool isCollegeStudentEmail(String raw) {
  final match = _emailPattern.firstMatch(normalizeEmail(raw));
  return match != null && AppConfig.studentEmailDomains.contains(match.group(1));
}

bool isDriverAccountEmail(String raw) =>
    normalizeEmail(raw).endsWith('@${AppConfig.driverEmailDomain}');

String normalizeDriverId(String raw) => raw.trim().toUpperCase();

bool isValidDriverId(String raw) =>
    _driverIdPattern.hasMatch(normalizeDriverId(raw));

/// The Firebase Auth email behind a driver ID. See [AppConfig.driverEmailDomain].
String driverEmailFor(String driverId) =>
    '${normalizeDriverId(driverId).toLowerCase()}@${AppConfig.driverEmailDomain}';

bool isValidPin(String raw) =>
    RegExp('^\\d{${AppConfig.driverPinLength}}\$').hasMatch(raw);
