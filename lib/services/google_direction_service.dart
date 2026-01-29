import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleDirectionsService {
  GoogleDirectionsService(this.apiKey);
  final String apiKey;

  Future<double> getDrivingDistanceKm({
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
      throw Exception(jsonData['error_message'] ?? jsonData['status']);
    }

    final meters =
    jsonData['routes'][0]['legs'][0]['distance']['value'] as num;

    return meters.toDouble() / 1000.0;
  }
}
