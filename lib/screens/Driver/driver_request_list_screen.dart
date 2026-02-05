import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/ride_repository.dart';
import '../../repositories/rider_request_repository.dart';
import 'driver_trip_map_screen.dart';

class DriverRequestListScreen extends StatefulWidget {
  const DriverRequestListScreen({super.key});

  @override
  State<DriverRequestListScreen> createState() => _DriverRequestListScreenState();
}

class _DriverRequestListScreenState extends State<DriverRequestListScreen> {
  final _rideRepo = RideRepository();
  final _riderReqRepo = RiderRequestRepository();

  @override
  void initState() {
    super.initState();

    // ✅ Activate any due scheduled requests when driver opens this page
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _activateDueScheduledRequestsForAllRiders();
      } catch (_) {
        // keep silent; this is just background activation
      }
    });
  }

  /// ✅ Drivers can activate "due" scheduled requests globally
  /// so scheduled requests become visible to drivers when time arrives.
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Ride Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                await _activateDueScheduledRequestsForAllRiders();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Updated scheduled requests')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No waiting requests',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final requestId = docs[index].id;

              return _RequestCard(
                pickup: (d['pickupAddress'] ?? '').toString(),
                destination: (d['destinationAddress'] ?? '').toString(),
                seats: (d['seatRequested'] ?? 1) as int,
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
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.pickup,
    required this.destination,
    required this.seats,
    required this.onAccept,
  });

  final String pickup;
  final String destination;
  final int seats;
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
          const Text(
            'New Ride Request',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('From: $pickup'),
          Text('To: $destination'),
          const SizedBox(height: 6),
          Text('Seats: $seats'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E73FF),
              ),
              child: const Text(
                'Accept Request',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
