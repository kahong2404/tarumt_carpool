import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PickupSearchPage extends StatefulWidget {
  const PickupSearchPage({super.key});

  @override
  State<PickupSearchPage> createState() => _PickupSearchPageState();
}

class _PickupSearchPageState extends State<PickupSearchPage> {
  final String _googleApiKey = "AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA";

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  GoogleMapController? _mapCtrl;

  static const LatLng _defaultTarget = LatLng(3.2149, 101.7291);
  LatLng _selectedLatLng = _defaultTarget;
  Marker? _marker;

  bool _loading = false;
  String? _error;

  List<PlacePrediction> _predictions = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // -------------------------------
  // Google Places AUTOCOMPLETE (HTTP)
  // -------------------------------
  Future<void> _searchPlaces(String input) async {
    if (input.trim().isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    final uri = Uri.https(
      "maps.googleapis.com",
      "/maps/api/place/autocomplete/json",
      {
        "input": input,
        "key": _googleApiKey,
        "components": "country:my",
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return;

    final data = json.decode(res.body);
    if (data["status"] != "OK") {
      setState(() => _predictions = []);
      return;
    }

    setState(() {
      _predictions = (data["predictions"] as List)
          .map((e) => PlacePrediction.fromJson(e))
          .toList();
    });
  }

  // -------------------------------
  // Google Place DETAILS (lat/lng)
  // -------------------------------
  Future<LatLng> _fetchLatLng(String placeId) async {
    final uri = Uri.https(
      "maps.googleapis.com",
      "/maps/api/place/details/json",
      {
        "place_id": placeId,
        "fields": "geometry/location",
        "key": _googleApiKey,
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

  // -------------------------------
  // When user taps a prediction
  // -------------------------------
  Future<void> _onPredictionSelected(PlacePrediction p) async {
    setState(() {
      _searchCtrl.text = p.description;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
      _predictions = [];
      _loading = true;
      _error = null;
    });

    try {
      final latLng = await _fetchLatLng(p.placeId);

      setState(() {
        _selectedLatLng = latLng;
        _marker = Marker(
          markerId: const MarkerId("pickup"),
          position: latLng,
          infoWindow: InfoWindow(title: "Pickup", snippet: p.description),
        );
      });

      await _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );
    } catch (e) {
      setState(() => _error = "Failed to load location");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultTarget,
              zoom: 16,
            ),
            onMapCreated: (c) => _mapCtrl = c,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: {
              if (_marker != null) _marker!,
            },
          ),

          // SEARCH BAR + RESULT LIST
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          ),

                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: "Search location",
                                border: InputBorder.none,
                              ),
                              onChanged: (text) {
                                _debounce?.cancel();
                                _debounce = Timer(
                                  const Duration(milliseconds: 400),
                                      () => _searchPlaces(text),
                                );
                              },
                            ),
                          ),

                          _loading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.search),
                        ],
                      ),
                    ),
                  ),

                  // AUTOCOMPLETE RESULTS
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            color: Colors.black.withOpacity(0.10),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = _predictions[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(p.description),
                            onTap: () => _onPredictionSelected(p),
                          );
                        },
                      ),
                    ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // PICKUP BUTTON
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Pickup Here action
                      // Navigator.pop(context, {
                      //   "lat": _selectedLatLng.latitude,
                      //   "lng": _selectedLatLng.longitude,
                      // });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E73FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Pickup Here",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------
// Prediction model
// -------------------------------
class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({
    required this.description,
    required this.placeId,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json["description"],
      placeId: json["place_id"],
    );
  }
}
