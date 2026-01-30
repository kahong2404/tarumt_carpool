import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

double distanceKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusKm = 6371;

  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
          cos(_deg2rad(lat1)) *
              cos(_deg2rad(lat2)) *
              sin(dLon / 2) *
              sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (pi / 180);

double distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0; // earth radius meters
  final dLat = _deg2rad2(b.latitude - a.latitude);
  final dLon = _deg2rad2(b.longitude - a.longitude);

  final lat1 = _deg2rad(a.latitude);
  final lat2 = _deg2rad(b.latitude);

  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(h), sqrt(1 - h));
  return r * c;
}

double _deg2rad2(double deg) => deg * (pi / 180.0);