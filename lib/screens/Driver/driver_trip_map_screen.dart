import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/ride_repository.dart';
import '../../services/driver_live_location_service.dart';
import '../../services/google_direction_service.dart';
import '../../utils/geo_utils.dart';

class DriverTripMapScreen extends StatefulWidget {
  const DriverTripMapScreen({
    super.key,
    required this.rideId,
    this.enableDistanceGate = true, // ✅ set false for testing
  });

  final String rideId;
  final bool enableDistanceGate;

  @override
  State<DriverTripMapScreen> createState() => _DriverTripMapScreenState();
}

class _DriverTripMapScreenState extends State<DriverTripMapScreen> {
  final _rideRepo = RideRepository();

  late final DriverLiveLocationService _liveLocationSvc;
  late final GoogleDirectionsService _directions;

  GoogleMapController? _mapCtrl;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _driverLatLng;
  String? _lastRouteKey;
  bool _loadingRoute = false;
  bool _actionLoading = false;

  double? _routeDistanceKm;
  String? _routeDurationText;
  double? _computedFare;

  // Pricing
  static const double _baseFare = 2.00;
  static const double _ratePerKm = 0.80;
  static const double _minFare = 3.00;
  static const double _maxFare = 50.00;

  // Distance gate thresholds (realistic)
  static const double _arriveRadiusMeters = 99999999999.0;
  static const double _completeRadiusMeters = 99999999999.0;

  double _calcFare(double km) {
    final raw = _baseFare + (_ratePerKm * km);
    final withMin = raw < _minFare ? _minFare : raw;
    final capped = withMin > _maxFare ? _maxFare : withMin;
    return double.parse(capped.toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    _directions = GoogleDirectionsService(
      'AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA',
    );
    _liveLocationSvc = DriverLiveLocationService(widget.rideId);
    _liveLocationSvc.start();
  }

  @override
  void dispose() {
    _liveLocationSvc.stop();
    _mapCtrl?.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _prettyStatus(String s) {
    switch (s) {
      case 'incoming':
        return 'Driver is coming';
      case 'arrived_pickup':
        return 'Arrived at pickup';
      case 'ongoing':
        return 'On the way';
      case 'arrived_destination':
        return 'Arrived at destination';
      case 'completed':
        return 'Completed';
      default:
        return s;
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _tooFarDialog({
    required String title,
    required double metersAway,
    required double requiredMeters,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          'You are still ${metersAway.toStringAsFixed(1)}m away.\n'
              'Move closer (within ${requiredMeters.toStringAsFixed(0)}m) to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _doTransition({
    required String rideId,
    required String nextStatus,
    required String title,
    required String message,
    required String confirmText,
    LatLng? gateTarget,
    double? gateMeters,
  }) async {
    if (_actionLoading) return;

    // ✅ distance gate (can be disabled for testing)
    if (widget.enableDistanceGate && gateTarget != null && gateMeters != null) {
      if (_driverLatLng == null) {
        await _tooFarDialog(
          title: 'No live location yet',
          metersAway: 9999,
          requiredMeters: gateMeters,
        );
        return;
      }

      final metersAway = distanceMeters(_driverLatLng!, gateTarget);
      if (metersAway > gateMeters) {
        await _tooFarDialog(
          title: 'Too far to confirm',
          metersAway: metersAway,
          requiredMeters: gateMeters,
        );
        return;
      }
    }

    final ok = await _confirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
    );
    if (!ok) return;

    setState(() => _actionLoading = true);
    try {
      await _rideRepo.updateRideStatus(
        rideId: rideId,
        nextStatus: nextStatus,
      );
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  ({LatLng from, LatLng to})? _decideRoute({
    required String status,
    required LatLng pickup,
    required LatLng destination,
  }) {
    switch (status) {
      case 'incoming':
        if (_driverLatLng == null) return null;
        return (from: _driverLatLng!, to: pickup);
      case 'arrived_pickup':
      case 'ongoing':
        return (from: pickup, to: destination);
      default:
        return null;
    }
  }

  Future<void> _drawRouteIfNeeded({
    required String key,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_loadingRoute || _lastRouteKey == key) return;
    _lastRouteKey = key;
    _loadingRoute = true;

    try {
      final result = await _directions.getRoute(
        origin: origin,
        destination: destination,
      );

      final km = result.distanceKm;
      final fare = _calcFare(km);

      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polyline,
            width: 5,
            color: Colors.blue,
          ),
        };
        _routeDistanceKm = km;
        _routeDurationText = result.durationText;
        _computedFare = fare;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _polylines = {};
          _routeDistanceKm = null;
          _routeDurationText = null;
          _computedFare = null;
        });
      }
    } finally {
      _loadingRoute = false;
    }
  }

  Future<void> _openGoogleMaps(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=${from.latitude},${from.longitude}'
          '&destination=${to.latitude},${to.longitude}'
          '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget? _buildActionBar({
    required String status,
    required LatLng pickup,
    required LatLng destination,
  }) {
    if (status == 'completed') return null;

    String? buttonText;
    VoidCallback? onPressed;

    if (status == 'incoming') {
      buttonText = 'I arrived at pickup';
      onPressed = () => _doTransition(
        rideId: widget.rideId,
        nextStatus: 'arrived_pickup',
        title: 'Confirm arrival',
        message: 'Confirm you arrived at pickup?',
        confirmText: 'Arrived',
        gateTarget: pickup,
        gateMeters: _arriveRadiusMeters,
      );
    } else if (status == 'arrived_pickup') {
      buttonText = 'Start trip';
      onPressed = () => _doTransition(
        rideId: widget.rideId,
        nextStatus: 'ongoing',
        title: 'Start trip',
        message: 'Confirm to start the trip now?',
        confirmText: 'Start',
      );
    } else if (status == 'ongoing') {
      buttonText = 'Arrived at destination';
      onPressed = () => _doTransition(
        rideId: widget.rideId,
        nextStatus: 'arrived_destination',
        title: 'Confirm arrival',
        message: 'Confirm you arrived at destination?',
        confirmText: 'Arrived',
        gateTarget: destination,
        gateMeters: _completeRadiusMeters,
      );
    } else if (status == 'arrived_destination') {
      buttonText = 'Complete ride';
      onPressed = () => _doTransition(
        rideId: widget.rideId,
        nextStatus: 'completed',
        title: 'Complete ride',
        message: 'Confirm to complete this ride?',
        confirmText: 'Complete',
        gateTarget: destination,
        gateMeters: _completeRadiusMeters,
      );
    }

    if (buttonText == null || onPressed == null) return null;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _actionLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E73FF),
          ),
          child: _actionLoading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(
            widget.enableDistanceGate
                ? buttonText
                : '$buttonText (TEST MODE)',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Navigation')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _rideRepo.streamRide(widget.rideId),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) return const Center(child: Text('Ride not found'));

          final status = (data['rideStatus'] ?? '').toString();

          final pickupGeo = data['pickupGeo'];
          final destinationGeo = data['destinationGeo'];
          if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
            return const Center(child: Text('Ride data missing locations'));
          }

          final pickupLatLng = LatLng(pickupGeo.latitude, pickupGeo.longitude);
          final destinationLatLng =
          LatLng(destinationGeo.latitude, destinationGeo.longitude);

          final liveGeo = data['driverLiveLocation'];
          if (liveGeo is GeoPoint) {
            _driverLatLng = LatLng(liveGeo.latitude, liveGeo.longitude);
          } else {
            _driverLatLng = null;
          }

          if (status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _liveLocationSvc.stop();
            });
          }

          _markers = {
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickupLatLng,
              infoWindow: const InfoWindow(title: 'Pickup'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: destinationLatLng,
              infoWindow: const InfoWindow(title: 'Destination'),
            ),
            if (_driverLatLng != null)
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLatLng!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
                infoWindow: const InfoWindow(title: 'You'),
              ),
          };

          final route = _decideRoute(
            status: status,
            pickup: pickupLatLng,
            destination: destinationLatLng,
          );

          if (route != null) {
            final key =
                '$status:${route.from.latitude},${route.from.longitude}->${route.to.latitude},${route.to.longitude}';
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _drawRouteIfNeeded(
                key: key,
                origin: route.from,
                destination: route.to,
              );
            });
          } else {
            _polylines = {};
            _lastRouteKey = null;
            _routeDistanceKm = null;
            _routeDurationText = null;
            _computedFare = null;
          }

          final actionBar = _buildActionBar(
            status: status,
            pickup: pickupLatLng,
            destination: destinationLatLng,
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng,
                  zoom: 14,
                ),
                onMapCreated: (c) => _mapCtrl = c,
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),

              if (route != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: actionBar == null ? 20 : 80,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(route.from, route.to),
                    icon: const Icon(Icons.navigation),
                    label: const Text(
                      'Open Google Maps',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E73FF),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),

              if (actionBar != null) actionBar,

              // ✅ optional: small badge to show testing mode
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.enableDistanceGate
                        ? Colors.black.withOpacity(0.35)
                        : Colors.orange.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.enableDistanceGate ? 'GATE ON' : 'TEST MODE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E73FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF1E73FF).withOpacity(0.25),
        ),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
