import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleDirectionsService {
  GoogleDirectionsService(this.apiKey);
  final String apiKey;

  /// ===============================
  /// 1️⃣ Get FULL ROUTE (polyline)
  /// ===============================
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final jsonData = json.decode(res.body);

    if (jsonData['status'] != 'OK') {
      throw Exception(
        jsonData['error_message'] ?? jsonData['status'],
      );
    }

    final route = jsonData['routes'][0];
    final leg = route['legs'][0];

    final encodedPolyline =
    route['overview_polyline']['points'] as String;

    return RouteResult(
      polyline: _decodePolyline(encodedPolyline),
      distanceKm:
      (leg['distance']['value'] as num).toDouble() / 1000.0,
      durationText: leg['duration']['text'] as String,
    );
  }

  /// ===============================
  /// 2️⃣ Distance ONLY (optional use)
  /// ===============================
  Future<double> getDrivingDistanceKm({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final res = await getRoute(
      origin: origin,
      destination: destination,
    );
    return res.distanceKm;
  }
}

/// ===============================
/// ROUTE RESULT MODEL
/// ===============================
class RouteResult {
  RouteResult({
    required this.polyline,
    required this.distanceKm,
    required this.durationText,
  });

  final List<LatLng> polyline;
  final double distanceKm;
  final String durationText;
}

/// ===============================
/// POLYLINE DECODER
/// ===============================
List<LatLng> _decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int b, shift = 0, result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final dlat =
    ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    final dlng =
    ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(
      LatLng(lat / 1E5, lng / 1E5),
    );
  }

  return points;
}
