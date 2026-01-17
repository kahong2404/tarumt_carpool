import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

import '../models/place_prediction.dart';
import '../repositories/places_repository.dart';
import '../widgets/location_search_bar.dart';

enum LocationSelectMode { pickup, dropoff }

class LocationSelectScreen extends StatefulWidget {
  const LocationSelectScreen({
    super.key,
    required this.mode,
    required this.initialTarget,
  });

  final LocationSelectMode mode;
  final LatLng initialTarget;

  bool get isPickup => mode == LocationSelectMode.pickup;

  String get markerTitle => isPickup ? "Pickup" : "Drop-off";
  String get buttonText => isPickup ? "Pickup Here" : "Drop-off Here";
  String get resultKey => isPickup ? "pickup" : "dropoff";
  String get currentLocationSnippet =>
      isPickup ? "Current location" : "Start from pickup area";

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}

class _LocationSelectScreenState extends State<LocationSelectScreen> {
  final _placesRepo = PlacesRepository(apiKey: "AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA");
  final TextEditingController _searchCtrl = TextEditingController();

  GoogleMapController? _mapCtrl;

  late LatLng _selectedLatLng;
  Marker? _marker;

  bool _loading = false;
  bool _movedToUserOnce = false;
  String? _error;

  List<PlacePrediction> _predictions = [];
  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialTarget;

    // optional: show a marker immediately at initialTarget
    _marker = Marker(
      markerId: const MarkerId("selected"),
      position: _selectedLatLng,
      infoWindow: InfoWindow(title: widget.markerTitle),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final perm = await Permission.locationWhenInUse.request();
      if (!perm.isGranted) return;

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

      if (!mounted) return;
      setState(() {
        _selectedLatLng = here;
        _marker = Marker(
          markerId: const MarkerId("selected"),
          position: here,
          infoWindow: InfoWindow(title: widget.markerTitle, snippet: widget.currentLocationSnippet),
        );
      });

      if (!_movedToUserOnce) {
        _movedToUserOnce = true;
        await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
      }
    } catch (_) {}
  }

  Future<void> _setMarker(LatLng latLng, {String? snippet}) async {
    setState(() {
      _selectedLatLng = latLng;
      _marker = Marker(
        markerId: const MarkerId("selected"),
        position: latLng,
        infoWindow: InfoWindow(title: widget.markerTitle, snippet: snippet),
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
            initialCameraPosition: CameraPosition(
              target: widget.initialTarget,
              zoom: 16,
            ),
            onMapCreated: (c) async {
              _mapCtrl = c;

              // For pickup: try move to real current location
              // For dropoff: you can keep this ON (still useful) or disable
              if (widget.isPickup) {
                await _initLocation();
              }
            },
            onTap: (latLng) => _setMarker(latLng, snippet: "Pinned on map"),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            markers: {if (_marker != null) _marker!},
          ),

          // custom my-location button
          Positioned(
            right: 16,
            bottom: 90,
            child: SafeArea(
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Colors.white,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    _movedToUserOnce = false;
                    await _initLocation();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.my_location, color: Colors.black87, size: 22),
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
                  LocationSearchBar(
                    controller: _searchCtrl,
                    loading: _loading,
                    onBack: () => Navigator.pop(context),
                    onClear: _clearSearch,
                    onChangedDebounced: _onSearchChangedDebounced,
                  ),

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
                        "label": widget.markerTitle,
                        "type": widget.resultKey,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E73FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      widget.buttonText,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
