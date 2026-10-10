// Loads data/base-data.json and data/route-paths.json into Firestore.
// Used by seed-emulators.mjs; works with any Admin SDK Firestore instance.

import { readFile } from 'node:fs/promises';
import { FieldValue } from 'firebase-admin/firestore';

const readJson = async (name) =>
  JSON.parse(await readFile(new URL(`../data/${name}`, import.meta.url), 'utf8'));

export async function importBaseData(db) {
  const base = await readJson('base-data.json');
  const paths = await readJson('route-paths.json');
  const batch = db.batch();

  for (const route of base.routes) {
    const path = paths[route.id];
    if (!path || path.distanceFromStartM.length !== route.stops.length) {
      throw new Error(`Path for ${route.id} is missing or out of date. Run: npm run build-paths`);
    }
    batch.set(db.doc(`routes/${route.id}`), {
      name: route.name,
      city: route.city,
      active: true,
      stops: route.stops.map((stop, i) => ({
        id: stop.id,
        name: stop.name,
        lat: stop.lat,
        lng: stop.lng,
        scheduledTime: stop.scheduledTime,
        distanceFromStartM: path.distanceFromStartM[i],
      })),
      // Lets security rules check a student's stop without reading the list.
      stopIds: route.stops.map((stop) => stop.id),
      path: path.polyline,
      distanceM: path.distanceM,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  for (const bus of base.buses) {
    let driverId = null;
    if (bus.driver) {
      const found = await db.collection('users').where('driverId', '==', bus.driver).limit(1).get();
      if (found.empty) throw new Error(`Bus ${bus.id}: no driver with ID ${bus.driver}`);
      driverId = found.docs[0].id;
    }
    batch.set(db.doc(`buses/${bus.id}`), {
      number: bus.number,
      capacity: bus.capacity,
      routeId: bus.routeId,
      driverId,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  for (const access of base.routeAccess) {
    batch.set(db.doc(`routeAccess/${access.routeId}`), { acceptsFrom: access.acceptsFrom });
  }

  await batch.commit();
  return { routes: base.routes.length, buses: base.buses.length };
}
