import { describe, expect, test } from 'vitest';

import { checkPass, parsePassCode, passCode, passWindow } from './passCode.js';
import { passIsCurrent, type PassHolder } from './boarding.js';

// Shared example: app/test/pass_code_test.dart checks the Dart version
// produces exactly this code.
const SECRET = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY='; // base64 of "0123456789abcdef0123456789abcdef"
const UID = 'student-demo';
const AT = Date.UTC(2026, 9, 12, 2, 0, 15); // 12 Oct 2026 07:30:15 IST
const EXPECTED = 'WIMB1.student-demo.59725680.2N3GJpd7DpNWIKpd';

describe('pass codes', () => {
  test('match the shared example, so the app and server agree', () => {
    expect(passWindow(AT)).toBe(59725680);
    expect(passCode(SECRET, UID, AT)).toBe(EXPECTED);
  });

  test('change every 30 seconds', () => {
    expect(passCode(SECRET, UID, AT + 14_000)).toBe(EXPECTED);
    expect(passCode(SECRET, UID, AT + 15_000)).not.toBe(EXPECTED);
  });

  test('are accepted for one window either side, then go stale', () => {
    const pass = parsePassCode(EXPECTED)!;
    expect(checkPass(pass, SECRET, AT)).toBe('ok');
    expect(checkPass(pass, SECRET, AT + 30_000)).toBe('ok');
    expect(checkPass(pass, SECRET, AT - 30_000)).toBe('ok');
    expect(checkPass(pass, SECRET, AT + 60_000)).toBe('stale');
  });

  test('cannot be forged or moved to another student', () => {
    const otherSecret = Buffer.from('another secret, another student!').toString('base64');
    expect(checkPass(parsePassCode(EXPECTED)!, otherSecret, AT)).toBe('badSignature');
    const swapped = EXPECTED.replace('student-demo', 'student-xyz');
    expect(checkPass(parsePassCode(swapped)!, SECRET, AT)).toBe('badSignature');
  });

  test('anything else is not a pass', () => {
    for (const raw of ['', 'hello', 'WIMB1.a.b.c', `WIMB2.${UID}.59725680.2N3GJpd7DpNWIKpd`, 42, null]) {
      expect(parsePassCode(raw)).toBeNull();
    }
  });
});

describe('pass validity', () => {
  const holder = (over: Partial<PassHolder> = {}): PassHolder => ({ passValid: true, passValidUntil: '2026-12-31', ...over });
  const day = new Date('2026-10-12T02:00:00Z');

  test('valid through the last day on the campus clock', () => {
    expect(passIsCurrent(holder(), day)).toBe(true);
    expect(passIsCurrent(holder({ passValidUntil: '2026-10-12' }), new Date('2026-10-12T18:00:00Z'))).toBe(true); // 23:30 IST
    expect(passIsCurrent(holder({ passValidUntil: '2026-10-12' }), new Date('2026-10-12T18:31:00Z'))).toBe(false); // 00:01 IST next day
  });

  test('no pass, or no end date, is not valid', () => {
    expect(passIsCurrent(holder({ passValid: false }), day)).toBe(false);
    expect(passIsCurrent(holder({ passValidUntil: null }), day)).toBe(false);
  });
});
