import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:tarumt_carpool/screens/Rider/rider_tab_scaffold.dart';
import '../../repositories/ride_repository.dart';
import '../../services/google_direction_service.dart';

class RiderTripMapScreen extends StatefulWidget {
  const RiderTripMapScreen({
    super.key,
    required this.rideId,
    this.autoExitOnCompleted = true, // ✅ default true
  });

  final String rideId;
  final bool autoExitOnCompleted;

  @override
  State<RiderTripMapScreen> createState() => _RiderTripMapScreenState();
}

class _RiderTripMapScreenState extends State<RiderTripMapScreen> {
  final _rideRepo = RideRepository();
  late final GoogleDirectionsService _directions;

  final _functions =
  FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  GoogleMapController? _mapCtrl;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _driverLatLng;

  String? _lastRouteKey;
  bool _loadingRoute = false;

  double? _routeDistanceKm;
  String? _routeDurationText;
  double? _computedFare;

  bool _exitDone = false; // ✅ prevent redirect loop
  bool _actionLoading = false;

  // pricing (display only)
  static const double _baseFare = 2.00;
  static const double _ratePerKm = 0.80;
  static const double _minFare = 3.00;
  static const double _maxFare = 50.00;

  double _calcFare(double km) {
    final raw = _baseFare + (_ratePerKm * km);
    final withMin = raw < _minFare ? _minFare : raw;
    final capped = withMin > _maxFare ? _maxFare : withMin;
    return double.parse(capped.toStringAsFixed(2));
  }

  String _prettyStatus(String s) {
    switch (s) {
      case 'incoming':
        return 'Driver is coming';
      case 'arrived_pickup':
        return 'Driver arrived at pickup';
      case 'ongoing':
        return 'On the way';
      case 'arrived_destination':
        return 'Arrived at destination';
      case 'completed':
        return 'Ride completed';
      case 'cancelled':
        return 'Ride cancelled';
      default:
        return s;
    }
  }

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
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
            child: const Text('No'),
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

  Future<void> _cancelRide() async {
    if (_actionLoading) return;

    final ok = await _confirm(
      title: 'Cancel ride',
      message: 'Are you sure you want to cancel this ride?\nIf payment is held, it will be refunded.',
      confirmText: 'Cancel ride',
    );
    if (!ok) return;

    setState(() => _actionLoading = true);
    try {
      final callable = _functions.httpsCallable('cancelRide');
      await callable.call({
        'rideId': widget.rideId,
        'by': 'rider',
        'reason': 'Rider cancelled',
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RiderTabScaffold()),
            (route) => false,
      );
    } catch (e) {
      await _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _directions = GoogleDirectionsService(
      'AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA',
    );
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
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
    if (_loadingRoute) return;
    if (_lastRouteKey == key) return;

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
      if (!mounted) return;
      setState(() {
        _polylines = {};
        _routeDistanceKm = null;
        _routeDurationText = null;
        _computedFare = null;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const RiderTabScaffold(),
              ),
                  (route) => false,
            );
          },
        ),
        title: const Text('Your Ride', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF1E73FF),
        actions: [
          IconButton(
            icon: _actionLoading
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.cancel),
            onPressed: _actionLoading ? null : _cancelRide,
            tooltip: 'Cancel ride',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _rideRepo.streamRide(widget.rideId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) return const Center(child: Text('Ride not found'));

          final status = (data['rideStatus'] ?? '').toString();

          // ✅ exit only once when completed/cancelled
          if (!_exitDone &&
              widget.autoExitOnCompleted &&
              (status == 'completed' || status == 'cancelled')) {
            _exitDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RiderTabScaffold()),
                    (route) => false,
              );
            });
          }

          final pickupGeo = data['pickupGeo'];
          final destinationGeo = data['destinationGeo'];

          if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
            return const Center(
              child: Text('Ride data missing pickup or destination'),
            );
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
                infoWindow: const InfoWindow(title: 'Driver'),
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

          final eta = _routeDurationText;
          final kmText = _routeDistanceKm == null
              ? null
              : '${_routeDistanceKm!.toStringAsFixed(1)} km';
          final fareText = _computedFare == null
              ? null
              : 'RM ${_computedFare!.toStringAsFixed(2)}';

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
                  bottom: 170,
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

              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(0.10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${_prettyStatus(status)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (eta != null) _InfoChip(label: 'ETA', value: eta),
                          if (kmText != null)
                            _InfoChip(label: 'Distance', value: kmText),
                          if (fareText != null)
                            _InfoChip(label: 'Fare', value: fareText),
                        ],
                      ),
                    ],
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
