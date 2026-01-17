import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/place_prediction.dart';

class PlacesRepository {
  final String apiKey;
  PlacesRepository({required this.apiKey});

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    String countryCode = "my",
    LatLng? biasLocation,
    int? radiusMeters,
  }) async {
    if (input.trim().isEmpty) return [];

    final params = <String, String>{
      "input": input,
      "key": apiKey,
      "components": "country:$countryCode",
    };

    if (biasLocation != null && radiusMeters != null) {
      params["location"] = "${biasLocation.latitude},${biasLocation.longitude}";
      params["radius"] = radiusMeters.toString();
    }

    final uri = Uri.https(
      "maps.googleapis.com",
      "/maps/api/place/autocomplete/json",
      params,
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);
    if (data["status"] != "OK") return [];

    return (data["predictions"] as List)
        .map((e) => PlacePrediction.fromJson(e))
        .toList();
  }

  Future<String> reverseGeocode(LatLng latLng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${latLng.latitude},${latLng.longitude}'
        '&key=$apiKey';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return '';

    final json = jsonDecode(res.body);
    final results = json['results'] as List<dynamic>;
    if (results.isEmpty) return '';

    return results.first['formatted_address'] ?? '';
  }

  Future<LatLng> fetchLatLng(String placeId) async {
    final uri = Uri.https(
      "maps.googleapis.com",
      "/maps/api/place/details/json",
      {
        "place_id": placeId,
        "fields": "geometry/location",
        "key": apiKey,
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}");
    }

    final data = json.decode(res.body);
    if (data["status"] != "OK") {
      throw Exception(data["error_message"] ?? data["status"]);
    }

    final loc = data["result"]["geometry"]["location"];
    return LatLng(
      (loc["lat"] as num).toDouble(),
      (loc["lng"] as num).toDouble(),
    );
  }
}
