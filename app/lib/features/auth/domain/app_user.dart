import '../../alerts/domain/alert_prefs.dart';

enum UserRole {
  student,
  driver,
  office;

  static UserRole? tryParse(Object? value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

/// A `users/{uid}` document.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    this.email,
    this.driverId,
    this.routeId,
    this.stopId,
    this.passValid = false,
    this.passValidUntil,
    this.language,
    this.alerts = const AlertPrefs(),
    this.dailyRider = true,
  });

  final String uid;
  final String name;
  final UserRole role;
  final String? email;
  final String? driverId;
  final String? routeId;
  final String? stopId;
  final bool passValid;

  /// Last day the pass is valid, YYYY-MM-DD, set by the office.
  final String? passValidUntil;

  /// `en` or `ta`. Null until a driver picks one at first login.
  final String? language;

  /// Notification choices; students only.
  final AlertPrefs alerts;

  /// False for a student who takes no college bus every day (a hosteller,
  /// or one with their own transport): no route to choose, evening seats
  /// booked when needed.
  final bool dailyRider;

  AppUser copyWith({
    String? name,
    String? routeId,
    String? stopId,
    String? language,
    AlertPrefs? alerts,
    bool? dailyRider,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        role: role,
        email: email,
        driverId: driverId,
        routeId: routeId ?? this.routeId,
        stopId: stopId ?? this.stopId,
        passValid: passValid,
        passValidUntil: passValidUntil,
        language: language ?? this.language,
        alerts: alerts ?? this.alerts,
        dailyRider: dailyRider ?? this.dailyRider,
      );

  /// Returns null when the document has no recognisable role, so a malformed
  /// profile is treated the same as a missing one.
  static AppUser? tryFromMap(String uid, Map<String, dynamic> data) {
    final role = UserRole.tryParse(data['role']);
    if (role == null) return null;
    return AppUser(
      uid: uid,
      name: data['name'] as String? ?? '',
      role: role,
      email: data['email'] as String?,
      driverId: data['driverId'] as String?,
      routeId: data['routeId'] as String?,
      stopId: data['stopId'] as String?,
      passValid: data['passValid'] as bool? ?? false,
      passValidUntil: data['passValidUntil'] as String?,
      language: data['language'] as String?,
      alerts: AlertPrefs.fromMap(data['alerts']),
      dailyRider: data['dailyRider'] as bool? ?? true,
    );
  }
}
