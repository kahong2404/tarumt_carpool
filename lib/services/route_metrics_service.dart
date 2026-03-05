import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_direction_service.dart';

class RouteMetrics {
  final double distanceKm;
  final String durationText;

  const RouteMetrics({
    required this.distanceKm,
    required this.durationText,
  });
}

class RouteMetricsService {
  final GoogleDirectionsService _directions;

  RouteMetricsService(this._directions);

  Future<RouteMetrics> computeFromLatLng({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final r = await _directions.getRoute(origin: origin, destination: destination);
    return RouteMetrics(
      distanceKm: r.distanceKm,
      durationText: r.durationText,
    );
  }

  Future<RouteMetrics> computeFromGeoPoints({
    required GeoPoint pickupGeo,
    required GeoPoint destinationGeo,
  }) async {
    final origin = LatLng(pickupGeo.latitude, pickupGeo.longitude);
    final dest = LatLng(destinationGeo.latitude, destinationGeo.longitude);
    return computeFromLatLng(origin: origin, destination: dest);
  }
}