import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase_bootstrap.dart';

enum SosResult {
  sent,

  /// No running trip to send about.
  noTrip,

  /// The phone could not reach the server.
  offline,
}

enum ShareResult { shared, noTrip, offline }

abstract interface class SafetyRepository {
  /// Tells the transport office: this bus, and where it is now.
  Future<SosResult> sendSos();

  /// A link a parent can open to follow the student's running trip. The
  /// token is null unless [ShareResult.shared].
  Future<({ShareResult result, String? token})> shareTrip();
}

class FirebaseSafetyRepository implements SafetyRepository {
  FirebaseSafetyRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>?> _call(String name) async {
    try {
      final response = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: callTimeout(const Duration(seconds: 20))))
          .call<Map<String, dynamic>>();
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'internal') return null;
      rethrow;
    }
  }

  @override
  Future<SosResult> sendSos() async {
    final data = await _call('sendSos');
    if (data == null) return SosResult.offline;
    return data['result'] == 'sent' ? SosResult.sent : SosResult.noTrip;
  }

  @override
  Future<({ShareResult result, String? token})> shareTrip() async {
    final data = await _call('shareTrip');
    if (data == null) return (result: ShareResult.offline, token: null);
    final token = data['token'] as String?;
    return data['result'] == 'shared' && token != null
        ? (result: ShareResult.shared, token: token)
        : (result: ShareResult.noTrip, token: null);
  }
}
