import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/pass/domain/pass_code.dart';

// The same example as functions/src/passCode.test.ts: the phone and the
// server must produce identical codes.
const _secret = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';
final _at = DateTime.utc(2026, 10, 12, 2, 0, 15); // 07:30:15 IST
const _expected = 'WIMB1.student-demo.59725680.2N3GJpd7DpNWIKpd';

void main() {
  test('matches the server for the shared example', () {
    expect(PassCode.windowAt(_at), 59725680);
    expect(PassCode.make(secretBase64: _secret, uid: 'student-demo', serverTime: _at), _expected);
  });

  test('changes every 30 seconds, and says how long is left', () {
    expect(PassCode.make(secretBase64: _secret, uid: 'student-demo', serverTime: _at.add(const Duration(seconds: 14))),
        _expected);
    expect(PassCode.make(secretBase64: _secret, uid: 'student-demo', serverTime: _at.add(const Duration(seconds: 15))),
        isNot(_expected));
    expect(PassCode.remaining(_at), const Duration(seconds: 15));
  });
}
