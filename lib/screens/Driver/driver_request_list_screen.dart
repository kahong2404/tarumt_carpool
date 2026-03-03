import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tarumt_carpool/theme/app_colors.dart';

import '../../repositories/ride_repository.dart';
import '../../services/driver_presence_service.dart';
import '../../utils/geo_utils.dart';
import 'driver_trip_map_screen.dart';

class DriverRequestListScreen extends StatefulWidget {
  const DriverRequestListScreen({super.key});

  @override
  State<DriverRequestListScreen> createState() => _DriverRequestListScreenState();
}

class _DriverRequestListScreenState extends State<DriverRequestListScreen> {
  final _auth = FirebaseAuth.instance;
  String? get _driverId => _auth.currentUser?.uid;

  final _rideRepo = RideRepository();

  DriverPresenceService? _presence;
  LatLng? _driverLatLng;

  Timer? _tickTimer;
  bool _runningTick = false;

  static const _tickEverySeconds = 10;

  // ✅ location state
  bool _checkingLocation = true;
  bool _permissionDenied = false;
  bool _permissionDeniedForever = false;
  bool _serviceDisabled = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocationFlow();
      if (!mounted) return;

      // Global tick: activate scheduled + expand radius
      _tickTimer = Timer.periodic(
        const Duration(seconds: _tickEverySeconds),
            (_) => _globalMatchTick(),
      );

      await _globalMatchTick();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _presence?.stop();
    super.dispose();
  }

  // ----------------------------
  // LOCATION FLOW
  // ----------------------------
  Future<void> _initLocationFlow() async {
    setState(() {
      _checkingLocation = true;
      _permissionDenied = false;
      _permissionDeniedForever = false;
      _serviceDisabled = false;
    });

    // 1) service enabled?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _checkingLocation = false;
        _serviceDisabled = true;
      });
      return;
    }

    // 2) permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      if (!mounted) return;
      setState(() {
        _checkingLocation = false;
        _permissionDenied = true;
      });
      return;
    }

    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _checkingLocation = false;
        _permissionDeniedForever = true;
      });
      return;
    }

    // 3) start presence service
    _presence ??= DriverPresenceService(
      onLocation: (latLng) {
        if (!mounted) return;

        // ✅ Only update if changed enough (extra safety)
        final prev = _driverLatLng;
        if (prev != null) {
          final moved = distanceMeters(prev, latLng);
          if (moved < 15) return;
        }

        setState(() => _driverLatLng = latLng);
      },
    );

    await _presence!.start();

    if (!mounted) return;
    setState(() => _checkingLocation = false);
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ----------------------------
  // MATCH TICK
  // ----------------------------
  Future<void> _globalMatchTick() async {
    if (_runningTick) return;
    _runningTick = true;

    try {
      await _activateDueScheduledRequestsForAllRiders();
      await _expandDueWaitingRequests();
    } catch (e) {
      debugPrint('❌ global tick failed: $e');
    } finally {
      _runningTick = false;
    }
  }

  Future<void> _activateDueScheduledRequestsForAllRiders() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snap = await FirebaseFirestore.instance
        .collection('riderRequests')
        .where('status', isEqualTo: 'scheduled')
        .where('scheduledAt', isLessThanOrEqualTo: now)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'waiting',
        'nextExpandAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _expandDueWaitingRequests() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snap = await FirebaseFirestore.instance
        .collection('riderRequests')
        .where('status', isEqualTo: 'waiting')
        .where('nextExpandAt', isLessThanOrEqualTo: now)
        .limit(50)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snap.docs) {
      final d = doc.data();

      final currentRadius = (d['searchRadiusKm'] is num)
          ? (d['searchRadiusKm'] as num).toDouble()
          : 2.0;

      final stepKm = (d['searchStepKm'] is num)
          ? (d['searchStepKm'] as num).toDouble()
          : 2.0;

      final maxKm = (d['maxRadiusKm'] is num)
          ? (d['maxRadiusKm'] as num).toDouble()
          : 20.0;

      if (currentRadius >= maxKm) {
        batch.update(doc.reference, {
          'nextExpandAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(seconds: 60)),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        continue;
      }

      final newRadius = currentRadius + stepKm;
      final clamped = newRadius > maxKm ? maxKm : newRadius;

      batch.update(doc.reference, {
        'searchRadiusKm': clamped,
        'nextExpandAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final driverLoc = _driverLatLng;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Ride Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _globalMatchTick();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requests updated')),
              );
            },
          ),
        ],
      ),
      body: _buildBody(driverLoc),
    );
  }

  Widget _buildBody(LatLng? driverLoc) {
    if (_checkingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_serviceDisabled) {
      return _StateCard(
        title: 'Location Services Off',
        message: 'Please turn on Location Services to view nearby requests.',
        primaryText: 'Open Location Settings',
        onPrimary: () async {
          await _openLocationSettings();
          if (!mounted) return;
          await _initLocationFlow();
        },
        secondaryText: 'Retry',
        onSecondary: _initLocationFlow,
      );
    }

    if (_permissionDeniedForever) {
      return _StateCard(
        title: 'Location Permission Required',
        message:
        'Location permission is permanently denied.\nPlease enable it in Settings.',
        primaryText: 'Open App Settings',
        onPrimary: () async {
          await _openAppSettings();
          if (!mounted) return;
          await _initLocationFlow();
        },
        secondaryText: 'Retry',
        onSecondary: _initLocationFlow,
      );
    }

    if (_permissionDenied) {
      return _StateCard(
        title: 'Location Permission Required',
        message: 'Please allow location permission to view ride requests nearby.',
        primaryText: 'Allow Permission',
        onPrimary: _initLocationFlow,
        secondaryText: 'Retry',
        onSecondary: _initLocationFlow,
      );
    }

    if (driverLoc == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Getting your location...\n(Please wait a moment)',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // ✅ main content (same as your original)
    return Column(
      children: [
        _ActiveRideSection(
          driverId: _driverId,
          rideRepo: _rideRepo,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('riderRequests')
                .where('status', isEqualTo: 'waiting')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Firestore error:\n${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No waiting requests',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              for (final doc in docs) {
                final d = doc.data();
                final gp = d['pickupGeo'];
                if (gp is! GeoPoint) continue;

                final radiusKm = (d['searchRadiusKm'] is num)
                    ? (d['searchRadiusKm'] as num).toDouble()
                    : 2.0;

                final pickup = LatLng(gp.latitude, gp.longitude);
                final meters = distanceMeters(driverLoc, pickup);
                final km = meters / 1000.0;

                if (km <= radiusKm) filtered.add(doc);
              }

              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No requests in your current area.\nWait for radius to expand...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final d = doc.data();
                  final requestId = doc.id;

                  final gp = d['pickupGeo'] as GeoPoint;
                  final pickup = LatLng(gp.latitude, gp.longitude);

                  final radiusKm = (d['searchRadiusKm'] is num)
                      ? (d['searchRadiusKm'] as num).toDouble()
                      : 2.0;

                  final meters = distanceMeters(driverLoc, pickup);
                  final km = meters / 1000.0;

                  return _RequestCard(
                    pickup: (d['pickupAddress'] ?? '').toString(),
                    destination: (d['destinationAddress'] ?? '').toString(),
                    seats: (d['seatRequested'] ?? 1) as int,
                    radiusKm: radiusKm,
                    distanceKm: km,
                    onAccept: () async {
                      try {
                        final rideId = await _rideRepo.acceptRequest(
                          requestId: requestId,
                        );

                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverTripMapScreen(rideId: rideId),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ----------------------------
// Small reusable UI card
// ----------------------------
class _StateCard extends StatelessWidget {
  final String title;
  final String message;
  final String primaryText;
  final FutureOr<void> Function() onPrimary;
  final String? secondaryText;
  final FutureOr<void> Function()? onSecondary;

  const _StateCard({
    required this.title,
    required this.message,
    required this.primaryText,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => onPrimary(),
                  child: Text(primaryText),
                ),
              ),
              if (secondaryText != null && onSecondary != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => onSecondary!(),
                    child: Text(secondaryText!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------
// Your existing cards (unchanged)
// ----------------------------
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.pickup,
    required this.destination,
    required this.seats,
    required this.radiusKm,
    required this.distanceKm,
    required this.onAccept,
  });

  final String pickup;
  final String destination;
  final int seats;
  final double radiusKm;
  final double distanceKm;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Ride Request', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('From: $pickup'),
          Text('To: $destination'),
          const SizedBox(height: 6),
          Text('Seats: $seats'),
          const SizedBox(height: 6),
          Text(
            'Distance: ${distanceKm.toStringAsFixed(2)} km  |  Radius: ${radiusKm.toStringAsFixed(1)} km',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E73FF)),
              child: const Text(
                'Accept Request',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRideSection extends StatelessWidget {
  const _ActiveRideSection({
    required this.driverId,
    required this.rideRepo,
  });

  final String? driverId;
  final RideRepository rideRepo;

  @override
  Widget build(BuildContext context) {
    if (driverId == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: rideRepo.streamDriverActiveRideModel(driverId!),
      builder: (context, snapshot) {
        final ride = snapshot.data;

        if (ride == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Active Ride',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('From: ${ride.pickupAddress ?? '-'}'),
                Text('To: ${ride.destinationAddress ?? '-'}'),
                const SizedBox(height: 6),
                Text(
                  'Status: ${ride.status}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverTripMapScreen(rideId: ride.id),
                        ),
                      );
                    },
                    child: const Text('Open Active Ride'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}