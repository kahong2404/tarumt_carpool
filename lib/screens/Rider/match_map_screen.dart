import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MatchStage { matched, ongoing, arrived, completeConfirm, completed }

class MatchMapScreen extends StatefulWidget {
  final String requestId;

  const MatchMapScreen({super.key, required this.requestId});

  @override
  State<MatchMapScreen> createState() => _MatchMapScreenState();
}

class _MatchMapScreenState extends State<MatchMapScreen> {
  GoogleMapController? _map;

  MatchStage _stage = MatchStage.matched;

  // Mock locations (replace later with Firestore)
  final LatLng driver = const LatLng(3.2138, 101.7278);
  final LatLng pickup = const LatLng(3.2149, 101.7291);
  final LatLng destination = const LatLng(3.2163, 101.7310);

  int etaMinutes = 15;

  String _title() {
    switch (_stage) {
      case MatchStage.matched:
        return 'Driver is Coming';
      case MatchStage.ongoing:
        return '${etaMinutes}M to Arrive';
      case MatchStage.arrived:
      case MatchStage.completeConfirm:
        return 'Arrived';
      case MatchStage.completed:
        return 'Ride Completed';
    }
  }

  String _buttonText() {
    switch (_stage) {
      case MatchStage.matched:
        return 'Start Trip';
      case MatchStage.ongoing:
        return 'Mark Arrived';
      case MatchStage.arrived:
        return 'Complete Ride';
      case MatchStage.completeConfirm:
        return 'Confirm Complete';
      case MatchStage.completed:
        return 'Done';
    }
  }

  Set<Marker> _markers() {
    return {
      Marker(
        markerId: const MarkerId('driver'),
        position: driver,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(markerId: const MarkerId('pickup'), position: pickup),
      Marker(
        markerId: const MarkerId('dest'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
      ),
    };
  }

  Set<Polyline> _polylines() {
    // Simple line now. Later use Directions API.
    final points = (_stage == MatchStage.matched)
        ? [driver, pickup]
        : [driver, destination];

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 6,
      ),
    };
  }

  Future<void> _confirmComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arrived at Location?'),
        content: const Text('Confirm to complete the ride.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Ride'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _stage = MatchStage.completed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride Completed ✅')),
      );
    }
  }

  Future<void> _next() async {
    switch (_stage) {
      case MatchStage.matched:
        setState(() => _stage = MatchStage.ongoing);
        return;
      case MatchStage.ongoing:
        setState(() => _stage = MatchStage.arrived);
        return;
      case MatchStage.arrived:
        setState(() => _stage = MatchStage.completeConfirm);
        await _confirmComplete();
        return;
      case MatchStage.completeConfirm:
      // handled by dialog flow
        return;
      case MatchStage.completed:
        if (!mounted) return;
        Navigator.pop(context); // back to home (or go to summary page)
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match ${widget.requestId}'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: pickup, zoom: 16),
            onMapCreated: (c) => _map = c,
            markers: _markers(),
            polylines: _polylines(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Bottom card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _title(),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress bar (optional)
                  LinearProgressIndicator(
                    value: _stage == MatchStage.matched
                        ? 0.25
                        : _stage == MatchStage.ongoing
                        ? 0.60
                        : _stage == MatchStage.arrived
                        ? 0.85
                        : 1.0,
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(_buttonText()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
