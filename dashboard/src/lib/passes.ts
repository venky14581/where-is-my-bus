/** Today on the campus clock, YYYY-MM-DD. */
export const campusToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });

/**
 * Same rule as the server (functions/src/boarding.ts): valid through the
 * whole of the last day.
 */
export function passState(s: { passValid: boolean; passValidUntil: string | null }, onDay = campusToday()): 'valid' | 'expired' | 'none' {
  if (!s.passValid || !s.passValidUntil) return 'none';
  return s.passValidUntil >= onDay ? 'valid' : 'expired';
}
