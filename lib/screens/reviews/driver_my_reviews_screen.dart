import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/review/rating_summary_service.dart';

class DriverMyReviewsScreen extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  DriverMyReviewsScreen({super.key});

  final _auth = FirebaseAuth.instance;
  final _reviewRepo = ReviewRepository();
  final _userRepo = UserRepository();
  final _summaryService = RatingSummaryService();

  @override
  Widget build(BuildContext context) {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reviewRepo.streamDriverVisibleReviews(driverId),
          builder: (context, snap) {
            if (snap.hasError) {
              return _EmptyCard('Error: ${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
            }

            final docs = snap.data!.docs;
            final stars = docs.map((d) => ((d.data()['ratingScore'] ?? 0) as num).toInt()).toList();
            final summary = _summaryService.build(stars);

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _SummaryCard(
                  avg: summary.avg,
                  count: summary.count,
                  breakdown: summary.breakdown,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reviews',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black54),
                ),
                const SizedBox(height: 8),

                if (docs.isEmpty)
                  const _EmptyCard('No reviews yet.')
                else
                  ...docs.map((doc) {
                    final d = doc.data();
                    final rideId = (d['rideId'] ?? '').toString();
                    final riderId = (d['riderId'] ?? '').toString();
                    final comment = (d['commentText'] ?? '').toString();
                    final score = ((d['ratingScore'] ?? 0) as num).toInt();
                    final ts = d['createdAt'] as Timestamp?;
                    final dateText = ts == null ? '' : ts.toDate().toString();

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _userRepo.getUserDocMap(riderId),
                      builder: (context, userSnap) {
                        final riderName = (userSnap.data?['name'] ?? 'Rider').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReviewCardDriver(
                            rideId: rideId,
                            riderName: riderName,
                            stars: score,
                            comment: comment,
                            dateText: dateText,
                          ),
                        );
                      },
                    );
                  }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.avg,
    required this.count,
    required this.breakdown,
  });

  final double avg;
  final int count;
  final Map<int, int> breakdown;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E73FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Driver Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              Text('($count ratings)', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),

          // Breakdown bars (5 to 1)
          ...[5, 4, 3, 2, 1].map((s) {
            final v = breakdown[s] ?? 0;
            final total = count == 0 ? 1 : count;
            final frac = v / total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 18, child: Text('$s', style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 6),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: Colors.black.withOpacity(0.06),
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 28, child: Text('$v', textAlign: TextAlign.right)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _ReviewCardDriver extends StatelessWidget {
  const _ReviewCardDriver({
    required this.rideId,
    required this.riderName,
    required this.stars,
    required this.comment,
    required this.dateText,
  });

  final String rideId;
  final String riderName;
  final int stars;
  final String comment;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E73FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ride ID: $rideId', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Rider: $riderName', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),
          _StarRow(value: stars),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.35), width: 1.6),
            ),
            child: Text(
              comment.trim().isEmpty ? '-' : comment.trim(),
              style: const TextStyle(color: Colors.black87, height: 1.3),
            ),
          ),

          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(dateText, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int value;
  const _StarRow({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 5);
    return Row(
      children: List.generate(5, (i) {
        final filled = (i + 1) <= v;
        return Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber, size: 26);
      }),
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
