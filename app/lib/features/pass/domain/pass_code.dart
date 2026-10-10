import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The rotating pass code behind the student's QR:
///
///     WIMB1.<uid>.<window>.<signature>
///
/// window is server time in 30-second steps; signature is the first 16
/// characters of base64url(HMAC-SHA256(secret, `<uid>.<window>`)). The server
/// checks it in functions/src/passCode.ts, and both are tested against the
/// same example, so keep them in step.
abstract final class PassCode {
  static const windowSeconds = 30;

  static int windowAt(DateTime serverTime) =>
      serverTime.millisecondsSinceEpoch ~/ 1000 ~/ windowSeconds;

  static String make({required String secretBase64, required String uid, required DateTime serverTime}) {
    final window = windowAt(serverTime);
    final mac = Hmac(sha256, base64.decode(secretBase64)).convert(utf8.encode('$uid.$window'));
    final signature = base64Url.encode(mac.bytes).substring(0, 16);
    return 'WIMB1.$uid.$window.$signature';
  }

  /// How long the code shown at [serverTime] has left before it changes.
  static Duration remaining(DateTime serverTime) {
    final intoWindow = serverTime.millisecondsSinceEpoch % (windowSeconds * 1000);
    return Duration(milliseconds: windowSeconds * 1000 - intoWindow);
  }
}
