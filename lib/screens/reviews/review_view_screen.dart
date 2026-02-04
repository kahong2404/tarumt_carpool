import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/rating_review.dart';
import '../../repositories/review_repository.dart';

class ReviewViewScreen extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String reviewId;
  const ReviewViewScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context) {
    final repo = ReviewRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Review Detail'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: repo.streamReviewById(reviewId),
          builder: (context, snap) {
            if (snap.hasError) {
              return _CenterCard(
                child: Text(
                  'Error: ${snap.error}',
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snap.data!.exists) {
              return const _CenterCard(
                child: Text(
                  'Review not found',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final r = RatingReview.fromDoc(snap.data!);

            if (r.status == 'deleted') {
              return const _CenterCard(
                child: Text(
                  'This review was removed.',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (r.visibility == 'hidden') {
              return const _CenterCard(
                child: Text(
                  'This review is under admin moderation and is currently hidden.\n\nPlease wait until admin approves (Unhide).',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final dateText = r.createdAt == null ? '' : r.createdAt!.toDate().toString();

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _ReviewCard(
                  rideId: r.rideId,
                  stars: r.ratingScore,
                  comment: r.commentText,
                  dateText: dateText,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String rideId;
  final int stars;
  final String comment;
  final String dateText;

  const _ReviewCard({
    required this.rideId,
    required this.stars,
    required this.comment,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final c = comment.trim();

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
          // Ride ID title (like your card title)
          Text(
            'Ride ID: $rideId',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          // Stars only (no number)
          _StarRow(value: stars),
          const SizedBox(height: 12),

          // Comment box with border (outlined look)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.35), width: 1.6),
            ),
            child: Text(
              c.isEmpty ? '-' : c,
              style: const TextStyle(height: 1.3, color: Colors.black87),
            ),
          ),

          // Date/time under textbox
          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              dateText,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
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
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 26,
        );
      }),
    );
  }
}

class _CenterCard extends StatelessWidget {
  final Widget child;
  const _CenterCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ),
    );
  }
}
