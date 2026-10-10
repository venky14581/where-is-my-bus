import { readFileSync } from 'node:fs';
import { describe, expect, test } from 'vitest';

import { busesFromCsv, parseCsv, routesFromCsv, slug } from '../../scripts/routes-csv.mjs';

const HEADER = 'route_id,route_name,city,stop_order,stop_id,stop_name,lat,lng,scheduled_time';
const sheet = (...rows) => [HEADER, ...rows].join('\n');

test('CSV cells may be quoted, with commas and quotes inside; blank lines are skipped', () => {
  expect(parseCsv('a,"b, c","say ""hi"""\r\n\r\n1,2,3\n')).toEqual([['a', 'b, c', 'say "hi"'], ['1', '2', '3']]);
  expect(slug('R.S. Puram  Bus Stand')).toBe('rs-puram-bus-stand');
});

test('the templates, made from the current data, read back exactly as base-data.json', () => {
  const base = JSON.parse(readFileSync('data/base-data.json', 'utf8'));
  const { routes, errors } = routesFromCsv(readFileSync('data/templates/stops-template.csv', 'utf8'));
  expect(errors).toEqual([]);
  expect(routes).toEqual(base.routes);
  const buses = busesFromCsv(readFileSync('data/templates/buses-template.csv', 'utf8'), routes.map((r) => r.id));
  expect(buses.errors).toEqual([]);
  expect(buses.buses).toEqual(base.buses);
});

describe('mistakes the office can make, each named with its row', () => {
  const good = [
    'r1,Town – Campus,Coimbatore,1,,Town Hall,10.9946,76.9618,7:10',
    'r1,Town – Campus,Coimbatore,2,,Amrita Campus,10.9027,76.9006,08:00',
  ];

  test('a correct sheet: stop IDs made from names, the last stop is the campus, times padded', () => {
    const { routes, errors } = routesFromCsv(sheet(...good));
    expect(errors).toEqual([]);
    expect(routes[0].stops.map((s) => [s.id, s.scheduledTime])).toEqual([['town-hall', '07:10'], ['campus', '08:00']]);
  });

  test('missing columns', () => {
    expect(routesFromCsv('route_id,stop_name\nr1,A').errors[0]).toMatch(/^Missing columns: route_name, city, stop_order, lat, lng, scheduled_time/);
  });

  test('times out of order, a bad time, swapped coordinates, a gap in numbering', () => {
    const { errors } = routesFromCsv(sheet(
      'r1,Town – Campus,Coimbatore,1,,Town Hall,10.9946,76.9618,07:10',
      'r1,Town – Campus,Coimbatore,2,,Ukkadam,76.962,10.9886,07:05',
      'r1,Town – Campus,Coimbatore,4,,Kuniyamuthur,10.9636,76.9545,7.25',
      'r1,Town – Campus,Coimbatore,5,,Amrita Campus,10.9027,76.9006,08:00',
    ));
    expect(errors).toEqual(expect.arrayContaining([
      expect.stringMatching(/^Row 3 \(r1, Ukkadam\): \d+ km from campus\. Are lat and lng swapped/),
      expect.stringMatching(/^Row 4 \(r1, Kuniyamuthur\): stop_order should be 3/),
      expect.stringMatching(/^Row 4 \(r1, Kuniyamuthur\): scheduled_time must be like 07:15/),
      'Route r1: Ukkadam (07:05) is not after Town Hall (07:10).',
    ]));
  });

  test('a route that does not end at the campus, a repeated stop, one stop only', () => {
    expect(routesFromCsv(sheet(good[0], 'r1,Town – Campus,Coimbatore,2,,Ukkadam,10.9886,76.962,07:20')).errors)
      .toContain('Row 3 (r1, Ukkadam): the last stop of every route must be the campus.');
    expect(routesFromCsv(sheet(good[0], good[0].replace(',1,', ',2,').replace('7:10', '07:20'), good[1].replace(',2,', ',3,'))).errors)
      .toContain('Row 3 (r1, Town Hall): stop_id "town-hall" is used twice on this route.');
    expect(routesFromCsv(sheet(good[1].replace(',2,', ',1,'))).errors).toContain('Route r1: needs at least two stops, the last being the campus.');
  });

  test('buses: seats, registration, unknown route, bad driver ID', () => {
    const { errors } = busesFromCsv([
      'bus_id,number,capacity,route_id,driver_id',
      'bus-01,TN 37 AB 1201,fifty,r1,DRV001',
      'bus-02,,50,r9,D 1',
      'bus-01,TN 37 AB 1203,45,r1,',
    ].join('\n'), ['r1']);
    expect(errors).toEqual([
      'Row 2 (bus-01): capacity must be a whole number of seats, 1 to 120.',
      'Row 3 (bus-02): no number (the registration, e.g. TN 37 AB 1201).',
      'Row 3 (bus-02): route r9 is not in the stops sheet.',
      'Row 3 (bus-02): driver_id like DRV001.',
      'Row 4 (bus-01): bus_id used twice.',
    ]);
  });
});
