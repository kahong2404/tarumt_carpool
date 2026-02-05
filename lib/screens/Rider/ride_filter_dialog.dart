import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:tarumt_carpool/widgets/LocationSearch/location_select_screen.dart';
import 'open_offers_list.dart';

class RideFilterDialog extends StatefulWidget {
  final RideOfferFilter initial;
  const RideFilterDialog({super.key, required this.initial});

  @override
  State<RideFilterDialog> createState() => _RideFilterDialogState();
}

class _RideFilterDialogState extends State<RideFilterDialog> {
  late double _radiusKm;
  late int _minSeats;
  late bool _sortByFareAsc;
  late NearbyMode _nearbyMode;

  GeoPoint? _centerGeo;
  String _centerAddress = 'Not selected';

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initial.radiusKm;
    _minSeats = widget.initial.minSeats;
    _sortByFareAsc = widget.initial.sortByFareAsc;
    _nearbyMode = widget.initial.nearbyMode;

    _centerGeo = widget.initial.centerGeo;
    _centerAddress = widget.initial.centerAddress ?? 'Not selected';
  }

  Future<void> _pickCenterLocation() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSelectScreen(
          mode: LocationSelectMode.pickup,
          initialTarget: LatLng(3.2149, 101.7291), // KL default
          autoMoveToMyLocation: true,
          customMarkerTitle: 'Filter Location',
          customButtonText: 'Use This Location',
          customResultKey: 'filter',
          customCurrentLocationSnippet: 'Current location',
        ),
      ),
    );

    if (res == null) return;

    final lat = (res["lat"] as num).toDouble();
    final lng = (res["lng"] as num).toDouble();
    final addr = (res["address"] ?? "Selected location").toString();

    setState(() {
      _centerGeo = GeoPoint(lat, lng);
      _centerAddress = addr;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCenter = _centerGeo != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Filter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Near pickup or dropoff
            Row(
              children: [
                const Text('Nearby to', style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                SegmentedButton<NearbyMode>(
                  segments: const [
                    ButtonSegment(value: NearbyMode.pickup, label: Text('Pickup')),
                    ButtonSegment(value: NearbyMode.dropoff, label: Text('Dropoff')),
                  ],
                  selected: {_nearbyMode},
                  onSelectionChanged: (s) => setState(() => _nearbyMode = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Select location
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickCenterLocation,
                icon: const Icon(Icons.place_outlined),
                label: Text(hasCenter ? 'Change location' : 'Select location'),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hasCenter ? _centerAddress : 'No location selected',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ),

            const SizedBox(height: 12),

            // Radius slider
            Row(
              children: [
                const Text('Radius (km)', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_radiusKm.toStringAsFixed(0)} km'),
              ],
            ),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 40,
              divisions: 39,
              onChanged: (v) => setState(() => _radiusKm = v),
            ),

            const SizedBox(height: 8),

            // Min seats
            Row(
              children: [
                const Text('Min seats', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                DropdownButton<int>(
                  value: _minSeats,
                  items: [1, 2, 3, 4, 5, 6]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _minSeats = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Sort by fare
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Sort by fare (low → high)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _sortByFareAsc,
              onChanged: (v) => setState(() => _sortByFareAsc = v),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const RideOfferFilter(
                          radiusKm: 10,
                          minSeats: 1,
                          sortByFareAsc: true,
                          nearbyMode: NearbyMode.pickup,
                          centerGeo: null,
                          centerAddress: null,
                        ),
                      );
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        RideOfferFilter(
                          radiusKm: _radiusKm,
                          centerGeo: _centerGeo,
                          centerAddress: _centerAddress,
                          nearbyMode: _nearbyMode,
                          minSeats: _minSeats,
                          sortByFareAsc: _sortByFareAsc,
                        ),
                      );
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
