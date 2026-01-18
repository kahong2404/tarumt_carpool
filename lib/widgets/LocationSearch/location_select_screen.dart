// location_select_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/place_prediction.dart';
import '../../repositories/places_repository.dart';
import 'location_search_bar.dart';
import 'package:tarumt_carpool/repositories/rider_request_repository.dart';

enum LocationSelectMode { pickup, dropoff }

class LocationSelectScreen extends StatefulWidget {
  const LocationSelectScreen({
    super.key,
    required this.mode,
    required this.initialTarget,

    // ✅ Make screen reusable (driver/rider)
    this.autoMoveToMyLocation = true,
    this.customMarkerTitle,
    this.customButtonText,
    this.customResultKey,
    this.customCurrentLocationSnippet,
  });

  final LocationSelectMode mode;
  final LatLng initialTarget;

  // ✅ NEW
  final bool autoMoveToMyLocation;
  final String? customMarkerTitle;
  final String? customButtonText;
  final String? customResultKey;
  final String? customCurrentLocationSnippet;

  bool get isPickup => mode == LocationSelectMode.pickup;

  String get markerTitle =>
      customMarkerTitle ?? (isPickup ? "Pickup" : "Drop-off");

  String get buttonText =>
      customButtonText ?? (isPickup ? "Pickup Here" : "Drop-off Here");

  String get resultKey =>
      customResultKey ?? (isPickup ? "pickup" : "dropoff");

  String get currentLocationSnippet =>
      customCurrentLocationSnippet ??
          (isPickup ? "Current location" : "Start from pickup area");

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}

class _LocationSelectScreenState extends State<LocationSelectScreen> {
  final _placesRepo = PlacesRepository(
    apiKey: "AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA",
  );
  final TextEditingController _searchCtrl = TextEditingController();

  GoogleMapController? _mapCtrl;

  late LatLng _selectedLatLng;
  Marker? _marker;

  bool _loading = false;
  bool _movedToUserOnce = false;
  String? _error;

  List<PlacePrediction> _predictions = [];
  final loc.Location _location = loc.Location();

  // ✅ store the final human address
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialTarget;

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

  // ✅ Reverse geocode lat/lng -> readable address
  Future<String?> _reverseGeocode(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isEmpty) return null;
      final p = placemarks.first;

      final parts = <String>[
        if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
        if ((p.thoroughfare ?? '').trim().isNotEmpty) p.thoroughfare!.trim(),
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty)
          p.administrativeArea!.trim(),
        if ((p.postalCode ?? '').trim().isNotEmpty) p.postalCode!.trim(),
      ];

      // remove duplicates
      final clean = <String>[];
      for (final s in parts) {
        if (!clean.contains(s)) clean.add(s);
      }

      final address = clean.join(', ').trim();
      return address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
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

      // ✅ use _setMarker so it will also reverse-geocode
      await _setMarker(here, snippet: widget.currentLocationSnippet);

      if (!_movedToUserOnce) {
        _movedToUserOnce = true;
        await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(here, 17));
      }
    } catch (_) {}
  }

  // ✅ Set marker + reverse geocode (so no coordinates shown)
  Future<void> _setMarker(LatLng latLng, {String? snippet}) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _selectedLatLng = latLng;
      _predictions = [];
      _error = null;

      _marker = Marker(
        markerId: const MarkerId("selected"),
        position: latLng,
        infoWindow: InfoWindow(title: widget.markerTitle, snippet: snippet),
      );
    });

    // ✅ get real address
    final address = await _reverseGeocode(latLng);

    if (!mounted) return;
    setState(() {
      _selectedAddress = address ?? snippet ?? "Selected location";

      // ✅ always show the address inside the search bar
      _searchCtrl.text = _selectedAddress!;
      _searchCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));

      _loading = false;
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
    final q = text.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() => _predictions = []);
      return;
    }

    final list = await _placesRepo.autocomplete(
      input: q,
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

      // ✅ use _setMarker so it will reverse-geocode too
      await _setMarker(latLng, snippet: p.description);

      await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
    } catch (_) {
      if (mounted) setState(() => _error = "Failed to load location");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    Navigator.pop(context, {
      "lat": _selectedLatLng.latitude,
      "lng": _selectedLatLng.longitude,
      "address": _selectedAddress ?? _searchCtrl.text.trim(), // ✅ real address
      "label": widget.markerTitle,
      "type": widget.resultKey,
    });
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

              // ✅ only auto-move if caller wants
              if (widget.autoMoveToMyLocation) {
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
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
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
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E73FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      widget.buttonText,
                      style: const TextStyle(
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
