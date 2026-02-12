import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../repositories/rider_request_repository.dart';
import 'rider_trip_map_screen.dart';
import 'rider_tab_scaffold.dart';

class RiderWaitingMapScreen extends StatefulWidget {
  const RiderWaitingMapScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<RiderWaitingMapScreen> createState() => _RiderWaitingMapScreenState();
}

class _RiderWaitingMapScreenState extends State<RiderWaitingMapScreen> {
  final _repo = RiderRequestRepository();

  GoogleMapController? _mapCtrl;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _navToRideDone = false;
  bool _cancelLoading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Go back?'),
                content: const Text(
                  'Your request will continue waiting.\nYou can come back anytime.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );

            if (shouldLeave == true && mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiderTabScaffold(),
                ),
                    (route) => false,
              );
            }
          },
        ),
        title: const Text('Waiting for driver', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF1E73FF),
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _repo.streamRequest(widget.requestId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('Request not found'));
          }

          final status = (data['status'] ?? '').toString();
          final activeRideId = (data['activeRideId'] ?? '').toString();

          // 🛡 SAFE GeoPoint read
          final pickupGeo = data['pickupGeo'];
          final destinationGeo = data['destinationGeo'];

          if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
            return const Center(
              child: Text('Location data missing'),
            );
          }

          final pickupLatLng =
          LatLng(pickupGeo.latitude, pickupGeo.longitude);
          final destinationLatLng =
          LatLng(destinationGeo.latitude, destinationGeo.longitude);

          // 📍 markers
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
          };

          // ➖ straight line between pickup & destination
          _polylines = {
            Polyline(
              polylineId: const PolylineId('pickup_to_dropoff'),
              points: [pickupLatLng, destinationLatLng],
              width: 4,
              color: Colors.black54,
            ),
          };

          // ✅ auto jump to RiderTripMapScreen once driver accepts
          if (!_navToRideDone &&
              status == 'incoming' &&
              activeRideId.isNotEmpty) {
            _navToRideDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => RiderTripMapScreen(
                    rideId: activeRideId,
                  ),
                ),
              );
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pickupLatLng,
                  zoom: 14,
                ),
                onMapCreated: (c) => _mapCtrl = c,
                markers: _markers,
                polylines: _polylines, // ✅ straight line
                zoomControlsEnabled: false,
                myLocationEnabled: true,
              ),

              // status panel + cancel
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
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status == 'waiting'
                            ? 'Waiting for a driver to accept...'
                            : 'Updating...',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),

                      // ❌ Cancel only while waiting
                      if (status == 'waiting')
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _cancelLoading
                                ? null
                                : () async {
                              setState(() => _cancelLoading = true);
                              try {
                                await _repo.cancelRequest(
                                  widget.requestId,
                                );
                                _snack('Request cancelled');

                                if (!mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const RiderTabScaffold(),
                                  ),
                                      (route) => false,
                                );
                              } catch (e) {
                                _snack('Failed: $e');
                              } finally {
                                if (mounted) {
                                  setState(() => _cancelLoading = false);
                                }
                              }
                            },
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
                              'Cancel Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
