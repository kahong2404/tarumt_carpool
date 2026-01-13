import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

import '../models/place_prediction.dart';
import '../repositories/places_repository.dart';
import '../widgets/location_search_bar.dart';

class PickupSearchScreen extends StatefulWidget {
  const PickupSearchScreen({super.key});

  @override
  State<PickupSearchScreen> createState() => _PickupSearchScreenState();
}

class _PickupSearchScreenState extends State<PickupSearchScreen> {
  // ✅ Use your Places key here
  final _placesRepo = PlacesRepository(apiKey: "AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA");

  final TextEditingController _searchCtrl = TextEditingController();

  GoogleMapController? _mapCtrl;

  static const LatLng _defaultTarget = LatLng(3.2149, 101.7291);
  LatLng _selectedLatLng = _defaultTarget;
  Marker? _marker;

  bool _loading = false;
  bool _movedToUserOnce = false;

  String? _error;

  List<PlacePrediction> _predictions = [];

  final loc.Location _location = loc.Location();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final perm = await Permission.locationWhenInUse.request();
      if (!perm.isGranted) {
        // permission not granted -> keep default TAR UMT
        return;
      }

      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final ok = await _location.requestService();
        if (!ok) return;
      }

      final pos = await _location.getLocation();
      final lat = pos.latitude;
      final lng = pos.longitude;
      if (lat == null || lng == null) return;

      final here = LatLng(lat, lng);

      // ✅ set marker + update selected
      if (!mounted) return;
      setState(() {
        _selectedLatLng = here;
        _marker = Marker(
          markerId: const MarkerId("pickup"),
          position: here,
          infoWindow: const InfoWindow(title: "Pickup", snippet: "Current location"),
        );
      });

      // ✅ move camera ONLY ONCE
      if (!_movedToUserOnce) {
        _movedToUserOnce = true;
        await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
      }
    } catch (_) {
      // fail -> keep TAR UMT default
    }
  }


  Future<void> _setMarker(LatLng latLng, {String? snippet}) async {
    setState(() {
      _selectedLatLng = latLng;
      _marker = Marker(
        markerId: const MarkerId("pickup"),
        position: latLng,
        infoWindow: InfoWindow(title: "Pickup", snippet: snippet),
      );
      _predictions = [];
      _error = null;
    });

    await _mapCtrl?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _predictions = [];
      _error = null;
    });
  }

  Future<void> _onSearchChangedDebounced(String text) async {
    // Make sure the clear (X) shows/hides
    if (mounted) setState(() {});

    final list = await _placesRepo.autocomplete(
      input: text,
      countryCode: "my",
      biasLocation: _selectedLatLng,
      radiusMeters: 30000,
    );

    if (!mounted) return;
    setState(() => _predictions = list);
  }

  Future<void> _onPredictionSelected(PlacePrediction p) async {
    setState(() {
      _searchCtrl.text = p.description;
      _searchCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
      _predictions = [];
      _loading = true;
      _error = null;
    });

    try {
      final latLng = await _placesRepo.fetchLatLng(p.placeId);
      await _setMarker(latLng, snippet: p.description);
      await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
    } catch (_) {
      if (mounted) setState(() => _error = "Failed to load location");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultTarget,
              zoom: 16,
            ),
            onMapCreated: (c) async {
              _mapCtrl = c;
              await _initLocation();
            },
            onTap: (latLng) => _setMarker(latLng, snippet: "Pinned on map"),

            // ✅ HIDE DEFAULT BUTTONS
            myLocationEnabled: true,        // keep blue dot
            myLocationButtonEnabled: false, // ❌ hide location button
            compassEnabled: false,           // ❌ hide rotation / compass button
            zoomControlsEnabled: false,      // hide + / -
            markers: {
              if (_marker != null) _marker!,
            },
          ),

// CUSTOM MY LOCATION BUTTON (bottom-right, above pickup)
          Positioned(
            right: 16,
            bottom: 90, // adjust if needed
            child: SafeArea(
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Colors.white,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    _movedToUserOnce = false; // so it can re-center again
                    await _initLocation();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  // Search bar
                  LocationSearchBar(
                    controller: _searchCtrl,
                    loading: _loading,
                    onBack: () => Navigator.pop(context),
                    onClear: _clearSearch,
                    onChangedDebounced: _onSearchChangedDebounced,
                  ),

                  // Prediction list
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
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
          ),

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
                      Navigator.pop(context, {
                        "lat": _selectedLatLng.latitude,
                        "lng": _selectedLatLng.longitude,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E73FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Pickup Here",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
