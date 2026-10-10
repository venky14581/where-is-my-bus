import { collection, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { alertFrom, type SafetyAlert } from '../lib/safety';
import { useQuery } from './hooks';

/** Open SOS, overspeed and off-route alerts, for any page's banner and badge. */
export function useOpenAlerts() {
  return useQuery<SafetyAlert>(query(collection(db, 'safetyAlerts'), where('status', '==', 'open')), alertFrom, 'open-alerts').data;
}
