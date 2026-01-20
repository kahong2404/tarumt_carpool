import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:tarumt_carpool/repositories/rider_request_repository.dart';
import 'package:tarumt_carpool/widgets/LocationSearch/location_select_screen.dart';
import 'package:tarumt_carpool/widgets/seat_request_dialog.dart';
import 'package:tarumt_carpool/utils/distance.dart';

import 'rider_home_header.dart';
import 'open_offers_list.dart';

class RiderHomeContent extends StatelessWidget {
  const RiderHomeContent({super.key});

  static const primary = Color(0xFF1E73FF);

  Future<void> _handleCreateRequest(BuildContext context) async {
    // 1) pick up
    final pickup = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSelectScreen(
          mode: LocationSelectMode.pickup,
          initialTarget: LatLng(3.2149, 101.7291),
        ),
      ),
    );
    if (pickup == null) return;

    final pickupLatLng = LatLng(pickup["lat"], pickup["lng"]);

    // 2) drop off
    final dropoff = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectScreen(
          mode: LocationSelectMode.dropoff,
          initialTarget: pickupLatLng,
        ),
      ),
    );
    if (dropoff == null) return;

    final originAddress = (pickup["address"] ?? "").toString().trim();
    final destinationAddress = (dropoff["address"] ?? "").toString().trim();
    // ===== KL-ONLY VALIDATION =====
    const klCenterLat = 3.2149;   // TARUMT / KL center
    const klCenterLng = 101.7291;
    const serviceRadiusKm = 40.0; // Klang Valley range

    final pickupKmFromKL = distanceKm(
      lat1: pickup["lat"],
      lon1: pickup["lng"],
      lat2: klCenterLat,
      lon2: klCenterLng,
    );

    final dropoffKmFromKL = distanceKm(
      lat1: dropoff["lat"],
      lon1: dropoff["lng"],
      lat2: klCenterLat,
      lon2: klCenterLng,
    );

    if (pickupKmFromKL > serviceRadiusKm ||
        dropoffKmFromKL > serviceRadiusKm) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only KL area is supported (within ${serviceRadiusKm.toInt()} km).\n'
                'Pickup: ${pickupKmFromKL.toStringAsFixed(1)} km, '
                'Destination: ${dropoffKmFromKL.toStringAsFixed(1)} km',
          ),
        ),
      );
      return;
    }
    // ===== END KL-ONLY VALIDATION =====

    // 3) seat count
    final seatRequested = await showDialog<int>(
      context: context,
      builder: (_) => const SeatRequestDialog(),
    );
    if (seatRequested == null) return;

    // 4) current time
    final now = DateTime.now();
    final rideDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final rideTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 5) save to firestore
    final repo = RiderRequestRepository();

    try {
      await repo.createRiderRequest(
        origin: originAddress,
        destination: destinationAddress,
        rideDate: rideDate,
        rideTime: rideTime,
        seatRequested: seatRequested,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request created ($seatRequested seat)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RiderHomeHeader(
          primaryColor: primary,
          onCreateRequestTap: () => _handleCreateRequest(context),
          onWalletTap: () {},
          onFilterTap: () {},
          onScheduleTap: () {},
        ),
        const SizedBox(height: 12),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: OpenOffersList(),
          ),
        ),
      ],
    );
  }
}
