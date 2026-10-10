import 'package:latlong2/latlong.dart';

const _distance = Distance();

/// Great-circle distance in metres.
double metresBetween(double lat1, double lng1, double lat2, double lng2) =>
    _distance.as(LengthUnit.Meter, LatLng(lat1, lng1), LatLng(lat2, lng2));

/// Decodes a Google encoded polyline (precision 5), the format OSRM returns
/// and `routes/{routeId}.path` stores.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextValue() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    // Not ~(result >> 1): on the web, bitwise operators give unsigned
    // 32-bit results, so ~ would turn small negatives into huge positives.
    return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
  }

  while (index < encoded.length) {
    lat += nextValue();
    lng += nextValue();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
