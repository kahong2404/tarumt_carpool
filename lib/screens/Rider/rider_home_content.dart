import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:tarumt_carpool/repositories/rider_request_repository.dart';
import 'package:tarumt_carpool/screens/Rider/rider_waiting_map_screen.dart';
import 'package:tarumt_carpool/services/google_direction_service.dart';
import 'package:tarumt_carpool/utils/geo_utils.dart';
import 'package:tarumt_carpool/widgets/LocationSearch/location_select_screen.dart';
import 'package:tarumt_carpool/widgets/seat_request_dialog.dart';

import 'rider_home_header.dart';
import 'open_offers_list.dart';
import 'ride_filter_dialog.dart';

class RiderHomeContent extends StatefulWidget {
  const RiderHomeContent({super.key});

  static const primary = Color(0xFF1E73FF);

  @override
  State<RiderHomeContent> createState() => _RiderHomeContentState();
}

class _RiderHomeContentState extends State<RiderHomeContent> {
  final RiderRequestRepository _repo = RiderRequestRepository();
  late final GoogleDirectionsService _directions;

  // ✅ filter state
  RideOfferFilter _filter = const RideOfferFilter();

  bool _busy = false;

  // pricing
  static const double _baseFare = 2.00;
  static const double _ratePerKm = 0.80; // you can change to 2.00 if you want
  static const double _minFare = 3.00;
  static const double _maxFare = 50.00;

  int _calcFareCents(double km) {
    final raw = _baseFare + (_ratePerKm * km);
    final withMin = raw < _minFare ? _minFare : raw;
    final capped = withMin > _maxFare ? _maxFare : withMin;
    return (capped * 100).round(); // cents int
  }

  @override
  void initState() {
    super.initState();

    _directions = GoogleDirectionsService('AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA');

    // ✅ keep scheduled activation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _repo.activateDueScheduledRequests();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- helpers ----------
  bool _validateKLOnly(BuildContext context, Map pickup, Map dropoff) {
    const klCenterLat = 3.2149;
    const klCenterLng = 101.7291;
    const serviceRadiusKm = 40.0;

    final pickupKmFromKL = distanceKm(
      lat1: klCenterLat,
      lon1: klCenterLng,
      lat2: pickup["lat"],
      lon2: pickup["lng"],
    );

    final dropoffKmFromKL = distanceKm(
      lat1: klCenterLat,
      lon1: klCenterLng,
      lat2: dropoff["lat"],
      lon2: dropoff["lng"],
    );

    if (pickupKmFromKL > serviceRadiusKm || dropoffKmFromKL > serviceRadiusKm) {
      _snack('Only KL area is supported (within ${serviceRadiusKm.toInt()} km).');
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>?> _pickPickup(BuildContext context) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSelectScreen(
          mode: LocationSelectMode.pickup,
          initialTarget: LatLng(3.2149, 101.7291),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickDropoff(BuildContext context, LatLng initialTarget) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectScreen(
          mode: LocationSelectMode.dropoff,
          initialTarget: initialTarget,
        ),
      ),
    );
  }

  Future<RouteResult> _computeRouteOrThrow({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      return await _directions.getRoute(origin: origin, destination: destination);
    } catch (e) {
      throw Exception('Failed to compute route. Please try again. ($e)');
    }
  }

  // ---------- create request now ----------
  Future<void> _handleCreateRequest(BuildContext context) async {
    if (_busy) return;

    final pickup = await _pickPickup(context);
    if (pickup == null) return;

    final pickupLatLng = LatLng(pickup["lat"], pickup["lng"]);

    final dropoff = await _pickDropoff(context, pickupLatLng);
    if (dropoff == null) return;

    if (!_validateKLOnly(context, pickup, dropoff)) return;

    final pickupAddress = (pickup["address"] ?? "").toString().trim();
    final destinationAddress = (dropoff["address"] ?? "").toString().trim();

    final seatRequested = await showDialog<int>(
      context: context,
      builder: (_) => const SeatRequestDialog(),
    );
    if (seatRequested == null) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final rideDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rideTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final destLatLng = LatLng(dropoff["lat"], dropoff["lng"]);

      final route = await _computeRouteOrThrow(
        origin: pickupLatLng,
        destination: destLatLng,
      );

      final finalFareCents = _calcFareCents(route.distanceKm);

      final requestId = await _repo.createRiderRequest(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        rideDate: rideDate,
        rideTime: rideTime,
        seatRequested: seatRequested,
        pickupGeo: GeoPoint(
          (pickup["lat"] as num).toDouble(),
          (pickup["lng"] as num).toDouble(),
        ),
        destinationGeo: GeoPoint(
          (dropoff["lat"] as num).toDouble(),
          (dropoff["lng"] as num).toDouble(),
        ),

        // ✅ store computed once
        finalFareCents: finalFareCents,
        routeDistanceKm: route.distanceKm,
        routeDurationText: route.durationText,
      );

      if (!mounted) return;

      _snack('Request created ($seatRequested seat)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RiderWaitingMapScreen(requestId: requestId)),
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- schedule booking ----------
  Future<void> _handleScheduleRequest(BuildContext context) async {
    if (_busy) return;

    final pickup = await _pickPickup(context);
    if (pickup == null) return;

    final pickupLatLng = LatLng(pickup["lat"], pickup["lng"]);

    final dropoff = await _pickDropoff(context, pickupLatLng);
    if (dropoff == null) return;

    if (!_validateKLOnly(context, pickup, dropoff)) return;

    final pickupAddress = (pickup["address"] ?? "").toString().trim();
    final destinationAddress = (dropoff["address"] ?? "").toString().trim();

    final seatRequested = await showDialog<int>(
      context: context,
      builder: (_) => const SeatRequestDialog(),
    );
    if (seatRequested == null) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10))),
    );
    if (time == null) return;

    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (scheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      _snack('Please choose a time at least 5 minutes later.');
      return;
    }

    setState(() => _busy = true);
    try {
      final destLatLng = LatLng(dropoff["lat"], dropoff["lng"]);

      final route = await _computeRouteOrThrow(
        origin: pickupLatLng,
        destination: destLatLng,
      );

      final finalFareCents = _calcFareCents(route.distanceKm);

      final requestId = await _repo.createScheduledRiderRequest(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        scheduledAt: scheduledAt,
        seatRequested: seatRequested,
        pickupGeo: GeoPoint(
          (pickup["lat"] as num).toDouble(),
          (pickup["lng"] as num).toDouble(),
        ),
        destinationGeo: GeoPoint(
          (dropoff["lat"] as num).toDouble(),
          (dropoff["lng"] as num).toDouble(),
        ),

        // ✅ store computed once
        finalFareCents: finalFareCents,
        routeDistanceKm: route.distanceKm,
        routeDurationText: route.durationText,
      );

      _snack('Scheduled booking created ($requestId)');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- filter ----------
  Future<void> _openFilterDialog() async {
    final result = await showModalBottomSheet<RideOfferFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RideFilterDialog(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              RiderHomeHeader(
                primaryColor: RiderHomeContent.primary,
                onCreateRequestTap: () => _handleCreateRequest(context),
                onWalletTap: () {},
                onFilterTap: _openFilterDialog,
                onScheduleTap: () => _handleScheduleRequest(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: OpenOffersList(filter: _filter),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _handleCreateRequest(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RiderHomeContent.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply New Ride',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ✅ simple loading overlay
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}