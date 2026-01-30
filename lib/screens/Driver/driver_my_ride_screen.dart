import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/ride_repository.dart';
import 'driver_trip_map_screen.dart';

class DriverMyRidesPage extends StatelessWidget {
  DriverMyRidesPage({super.key});

  final _auth = FirebaseAuth.instance;
  final _repo = RideRepository();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not signed in'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const Text(
              'My Rides',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),

            // ✅ ACTIVE RIDE
            const _SectionTitle('Active ride'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.streamDriverActiveRide(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _EmptyCard('Active error: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const _CardLoading();
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const _EmptyCard('No active ride right now.');
                }

                final d = docs.first.data();
                final rideId = docs.first.id;

                return _RideCard(
                  title: 'Active ride',
                  status: (d['rideStatus'] ?? '').toString(),
                  pickup: (d['pickupAddress'] ?? '').toString(),
                  destination: (d['destinationAddress'] ?? '').toString(),
                  primaryButtonText: 'Resume',
                  onPrimary: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverTripMapScreen(rideId: rideId),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 18),

            // ✅ HISTORY
            const _SectionTitle('History'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.streamDriverRideHistory(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _EmptyCard('History error: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const _ListLoading();
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const _EmptyCard('No ride history yet.');
                }

                return Column(
                  children: docs.map((doc) {
                    final d = doc.data();
                    final rideId = doc.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RideCard(
                        title: 'Ride',
                        status: (d['rideStatus'] ?? '').toString(),
                        pickup: (d['pickupAddress'] ?? '').toString(),
                        destination: (d['destinationAddress'] ?? '').toString(),
                        primaryButtonText: 'View',
                        onPrimary: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverTripMapScreen(rideId: rideId),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Colors.black54,
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.title,
    required this.status,
    required this.pickup,
    required this.destination,
    required this.primaryButtonText,
    required this.onPrimary,
  });

  final String title;
  final String status;
  final String pickup;
  final String destination;
  final String primaryButtonText;
  final VoidCallback onPrimary;

  String _prettyStatus(String s) {
    switch (s) {
      case 'incoming':
        return 'Incoming';
      case 'arrived_pickup':
        return 'Arrived pickup';
      case 'ongoing':
        return 'Ongoing';
      case 'arrived_destination':
        return 'Arrived destination';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(_prettyStatus(status)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Pickup: $pickup', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 4),
          Text('Dropoff: $destination', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E73FF),
              ),
              child: Text(
                primaryButtonText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E73FF).withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E73FF).withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
