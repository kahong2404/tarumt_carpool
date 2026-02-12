import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/ride_repository.dart';
import 'rider_trip_map_screen.dart';
import 'rider_waiting_map_screen.dart'; // ✅ NEW: import waiting screen

// ✅ Review screens
import '../reviews/rider_submit_review_screen.dart';
import '../reviews/review_view_screen.dart';

class RiderMyRidesScreen extends StatelessWidget {
  RiderMyRidesScreen({super.key});

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

            // ✅ ACTIVE
            const _SectionTitle('Active ride'),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.streamRiderActiveRide(uid),
              builder: (context, rideSnap) {
                if (rideSnap.hasError) {
                  return _EmptyCard('Active ride error: ${rideSnap.error}');
                }
                if (!rideSnap.hasData) return const _CardLoading();

                final rideDocs = rideSnap.data!.docs;

                // ✅ If active ride exists -> show ride (incoming/ongoing/etc)
                if (rideDocs.isNotEmpty) {
                  final d = rideDocs.first.data();
                  final rideId = rideDocs.first.id;

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
                          builder: (_) => RiderTripMapScreen(
                            rideId: rideId,
                            autoExitOnCompleted: true,
                          ),
                        ),
                      );
                    },
                  );
                }

                // ✅ Else: show active request (waiting/scheduled/incoming)
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _repo.streamRiderActiveRequest(uid),
                  builder: (context, reqSnap) {
                    if (reqSnap.hasError) {
                      return _EmptyCard('Active request error: ${reqSnap.error}');
                    }
                    if (!reqSnap.hasData) return const _CardLoading();

                    final reqDocs = reqSnap.data!.docs;
                    if (reqDocs.isEmpty) {
                      return const _EmptyCard('No active ride right now.');
                    }

                    final reqDoc = reqDocs.first;
                    final r = reqDoc.data();

                    final requestId = reqDoc.id;
                    final status = (r['status'] ?? '').toString();
                    final activeRideId = (r['activeRideId'] ?? '').toString();

                    // ✅ Decide where "Resume" should go
                    VoidCallback? onPrimary;
                    String primaryText = 'Resume';

                    if (status == 'waiting' || status == 'scheduled') {
                      primaryText = 'Resume Waiting';
                      onPrimary = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderWaitingMapScreen(
                              requestId: requestId,
                            ),
                          ),
                        );
                      };
                    } else if (status == 'incoming' && activeRideId.isNotEmpty) {
                      primaryText = 'Open Ride';
                      onPrimary = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderTripMapScreen(
                              rideId: activeRideId,
                              autoExitOnCompleted: true,
                            ),
                          ),
                        );
                      };
                    } else {
                      // fallback (rare)
                      primaryText = 'Waiting...';
                      onPrimary = null;
                    }

                    return _RideCard(
                      title: status == 'scheduled'
                          ? 'Scheduled request'
                          : (status == 'waiting' ? 'Searching driver' : 'Driver found'),
                      status: status,
                      pickup: (r['pickupAddress'] ?? '').toString(),
                      destination: (r['destinationAddress'] ?? '').toString(),
                      primaryButtonText: primaryText,
                      onPrimary: onPrimary ?? () {}, // keeps UI safe
                      // optional: if disabled
                      primaryDisabled: onPrimary == null,
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
              stream: _repo.streamRiderRideHistory(uid),
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

                    final status = (d['rideStatus'] ?? '').toString();

                    final hasReview = (d['hasReview'] == true);
                    final reviewId = (d['reviewId'] ?? '').toString().trim();

                    final canWrite = status == 'completed' && !hasReview;
                    final canViewReview = status == 'completed' && reviewId.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RideCard(
                        title: 'Ride',
                        status: status,
                        pickup: (d['pickupAddress'] ?? '').toString(),
                        destination: (d['destinationAddress'] ?? '').toString(),
                        primaryButtonText: 'View',
                        onPrimary: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RiderTripMapScreen(
                                rideId: rideId,
                                autoExitOnCompleted: false,
                              ),
                            ),
                          );
                        },
                        secondaryButtonText: canWrite
                            ? 'Write Review'
                            : (canViewReview ? 'View Review' : null),
                        onSecondary: canWrite
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RiderSubmitReviewScreen(rideId: rideId),
                            ),
                          );
                        }
                            : (canViewReview
                            ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewViewScreen(reviewId: reviewId),
                            ),
                          );
                        }
                            : null),
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
    this.primaryDisabled = false,
    this.secondaryButtonText,
    this.onSecondary,
  });

  final String title;
  final String status;
  final String pickup;
  final String destination;

  final String primaryButtonText;
  final VoidCallback onPrimary;
  final bool primaryDisabled;

  final String? secondaryButtonText;
  final VoidCallback? onSecondary;

  String _prettyStatus(String s) {
    switch (s) {
      case 'scheduled':
        return 'Scheduled';
      case 'waiting':
        return 'Waiting';
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
    const primary = Color(0xFF1E73FF);

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

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: primaryDisabled ? null : onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryButtonText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              if (secondaryButtonText != null && onSecondary != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary.withOpacity(0.65)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        secondaryButtonText!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
    const primary = Color(0xFF1E73FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.25)),
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
