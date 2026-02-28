import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarumt_carpool/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tarumt_carpool/screens/Rider/rider_tab_scaffold.dart';
import '../../repositories/ride_repository.dart';
import '../../services/google_direction_service.dart';

class RiderTripMapScreen extends StatefulWidget {
  const RiderTripMapScreen({
    super.key,
    required this.rideId,
    this.autoExitOnCompleted = true,
  });

  final String rideId;
  final bool autoExitOnCompleted;

  @override
  State<RiderTripMapScreen> createState() => _RiderTripMapScreenState();
}

class _RiderTripMapScreenState extends State<RiderTripMapScreen> {
  final _rideRepo = RideRepository();
  late final GoogleDirectionsService _directions;

  GoogleMapController? _mapCtrl;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _driverLatLng;

  String? _lastRouteKey;
  bool _loadingRoute = false;

  double? _routeDistanceKm;
  String? _routeDurationText;

  bool _exitDone = false;
  bool _cancelLoading = false;

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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _polylines = {};
        _routeDistanceKm = null;
        _routeDurationText = null;
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

  Future<bool> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text('This will cancel the ride.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _cancelRideAsRider(String status) async {
    if (_cancelLoading) return;

    if (status != 'incoming') return;

    final ok = await _confirmCancel();
    if (!ok) return;

    setState(() => _cancelLoading = true);
    try {
      await _rideRepo.cancelRideByRider(rideId: widget.rideId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),  // entire page background color
      appBar: AppBar(
        backgroundColor: AppColors.brandBlue, // app bar background color
        foregroundColor: Colors.white, // app bar foreground color
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const RiderTabScaffold(skipAutoResumeOnce: true),
              ),
                  (route) => false,
            );
          },
        ),
        title: const Text('Your Ride'),
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
          }

          // ✅ Fare comes from Firestore (rides.finalFare) in cents (int)
          final finalFareCents = (data['finalFare'] as num?)?.toInt();
          final fareText = (finalFareCents == null)
              ? null
              : 'RM ${(finalFareCents / 100).toStringAsFixed(2)}';

          final eta = _routeDurationText;
          final kmText = _routeDistanceKm == null
              ? null
              : '${_routeDistanceKm!.toStringAsFixed(1)} km';

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
                  bottom: 250,
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
                bottom: 60,
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

                      // ✅ Rider cancel only while incoming
                      if (status == 'incoming')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _cancelLoading
                                  ? null
                                  : () => _cancelRideAsRider(status),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: _cancelLoading
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Cancel Ride',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
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
