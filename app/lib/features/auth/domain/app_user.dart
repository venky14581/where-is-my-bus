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
    this.language,
  });

  final String uid;
  final String name;
  final UserRole role;
  final String? email;
  final String? driverId;
  final String? routeId;
  final String? stopId;
  final bool passValid;

  /// `en` or `ta`. Null until a driver picks one at first login.
  final String? language;

  AppUser copyWith({String? name, String? routeId, String? stopId, String? language}) => AppUser(
        uid: uid,
        name: name ?? this.name,
        role: role,
        email: email,
        driverId: driverId,
        routeId: routeId ?? this.routeId,
        stopId: stopId ?? this.stopId,
        passValid: passValid,
        language: language ?? this.language,
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
      language: data['language'] as String?,
    );
  }
}
