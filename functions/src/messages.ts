import type { AlertKind } from './audience.js';

export type Language = 'en' | 'ta';

export interface MessageParams {
  busNumber?: string;
  routeName?: string;
  stopName?: string;
  stopsAway?: number;
  minutes?: number;
  title?: string;
  body?: string;
}

/**
 * Push notification text, in the student's language. The in-app alerts list
 * renders its own text from the same kind and params, in the app's language.
 */
export function render(kind: AlertKind, language: Language, p: MessageParams): { title: string; body: string } {
  const bus = p.busNumber ?? '';
  if (language === 'ta') {
    switch (kind) {
      case 'tripStarted':
        return { title: 'பேருந்து புறப்பட்டது', body: `${bus} (${p.routeName ?? ''}) பயணத்தைத் தொடங்கியது.` };
      case 'approaching':
        return {
          title: 'உங்கள் பேருந்து வருகிறது',
          body: `${bus} ${p.stopName ?? ''} நிறுத்தத்திலிருந்து ${p.stopsAway} நிறுத்தங்கள் தொலைவில் உள்ளது.`,
        };
      case 'delay':
        return { title: 'பேருந்து தாமதம்', body: `${bus} சுமார் ${p.minutes} நிமிடங்கள் தாமதமாக ஓடுகிறது.` };
      case 'late':
        return { title: 'பேருந்து தாமதம்', body: `${bus} தாமதமாக வரும் என ஓட்டுநர் தெரிவித்துள்ளார்.` };
      case 'breakdown':
        return {
          title: 'பேருந்து பழுது',
          body: `${bus} பழுதடைந்துள்ளது. போக்குவரத்து அலுவலகத்தின் அறிவிப்புக்குக் காத்திருக்கவும்.`,
        };
      case 'announcement':
        return { title: p.title ?? 'அறிவிப்பு', body: p.body ?? '' };
    }
  }
  switch (kind) {
    case 'tripStarted':
      return { title: 'Your bus has started', body: `${bus} (${p.routeName ?? ''}) is on its way.` };
    case 'approaching':
      return {
        title: 'Your bus is coming',
        body: `${bus} is ${p.stopsAway} ${p.stopsAway === 1 ? 'stop' : 'stops'} from ${p.stopName ?? 'your stop'}.`,
      };
    case 'delay':
      return { title: 'Bus running late', body: `${bus} is running about ${p.minutes} min behind schedule.` };
    case 'late':
      return { title: 'Bus running late', body: `The driver of ${bus} reports the bus is running late.` };
    case 'breakdown':
      return { title: 'Bus breakdown', body: `${bus} has broken down. Watch for news from the transport office.` };
    case 'announcement':
      return { title: p.title ?? 'Announcement', body: p.body ?? '' };
  }
}
