// The rotating pass code shown as a QR on the student's phone.
//
//   WIMB1.<uid>.<window>.<signature>
//
// window    = seconds since 1970 (server time) / 30, rounded down
// signature = HMAC-SHA256(secret, "<uid>.<window>"), base64url, first 16
//             characters (96 bits)
//
// The secret lives in passSecrets/{uid}, readable only by that student and
// the server. The app computes the same code in
// app/lib/features/pass/domain/pass_code.dart; both are tested against the
// same example, so keep them in step.

import { createHmac, timingSafeEqual } from 'node:crypto';

export const PASS_WINDOW_SECONDS = 30;

/** Codes from this many windows either side still count, for clock drift and slow scans. */
export const PASS_WINDOW_SLACK = 1;

const PREFIX = 'WIMB1';

export function passWindow(epochMs: number): number {
  return Math.floor(epochMs / 1000 / PASS_WINDOW_SECONDS);
}

export function passSignature(secretBase64: string, uid: string, window: number): string {
  return createHmac('sha256', Buffer.from(secretBase64, 'base64'))
    .update(`${uid}.${window}`)
    .digest('base64url')
    .slice(0, 16);
}

export function passCode(secretBase64: string, uid: string, epochMs: number): string {
  const window = passWindow(epochMs);
  return `${PREFIX}.${uid}.${window}.${passSignature(secretBase64, uid, window)}`;
}

export type ParsedPass = { uid: string; window: number; signature: string };

/** Null for anything that is not a pass code at all. */
export function parsePassCode(raw: unknown): ParsedPass | null {
  if (typeof raw !== 'string' || raw.length > 200) return null;
  const parts = raw.trim().split('.');
  if (parts.length !== 4 || parts[0] !== PREFIX) return null;
  const [, uid, windowText, signature] = parts;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || !/^\d{1,12}$/.test(windowText) || !/^[A-Za-z0-9_-]{16}$/.test(signature)) {
    return null;
  }
  return { uid, window: Number(windowText), signature };
}

export type PassCheck = 'ok' | 'badSignature' | 'stale';

/** Whether [pass] was made with [secretBase64] within the allowed time. */
export function checkPass(pass: ParsedPass, secretBase64: string, nowMs: number): PassCheck {
  const expected = Buffer.from(passSignature(secretBase64, pass.uid, pass.window));
  const given = Buffer.from(pass.signature);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return 'badSignature';
  return Math.abs(passWindow(nowMs) - pass.window) <= PASS_WINDOW_SLACK ? 'ok' : 'stale';
}
