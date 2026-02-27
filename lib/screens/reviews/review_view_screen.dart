import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/models/rating_review.dart';
import 'package:tarumt_carpool/repositories/review_repository.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';

// split review widgets
import 'package:tarumt_carpool/widgets/reviews/star_row.dart';
import 'package:tarumt_carpool/widgets/reviews/review_comment_box.dart';
import 'package:tarumt_carpool/widgets/reviews/center_info_card.dart';
import 'package:tarumt_carpool/widgets/reviews/user_header.dart';

class ReviewViewScreen extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String reviewId;
  const ReviewViewScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context) {
    final repo = ReviewRepository();
    final userRepo = UserRepository();

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
              return const CenterInfoCard(
                child: Text('Failed to load review'),
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snap.data!.exists) {
              return const CenterInfoCard(
                child: Text('Review not found'),
              );
            }

            final r = RatingReview.fromDoc(snap.data!);

            if (r.status == 'deleted') {
              return const CenterInfoCard(
                child: Text('This review was removed'),
              );
            }

            if (r.visibility == 'hidden') {
              return const CenterInfoCard(
                child: Text(
                  'This review is under moderation.\nPlease wait for admin approval.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final dateText = r.createdAt?.toDate().toString() ?? '';

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
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

                      /// Ride ID
                      Text(
                        'Ride ID: ${r.rideId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// ⭐ CENTERED STAR
                      Center(
                        child: StarRow(value: r.ratingScore),
                      ),

                      const SizedBox(height: 12),

                      /// 👤 CENTERED DRIVER HEADER (below star)
                      Center(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: (r.driverId.isEmpty)
                              ? Future.value(null)
                              : userRepo.getUserDocMap(r.driverId),
                          builder: (context, userSnap) {
                            final user = userSnap.data;
                            final name =
                            (user?['name'] ?? 'Driver').toString();

                            final rawPhoto =
                            (user?['photoUrl'] ?? '')
                                .toString()
                                .trim();

                            final photoUrl =
                            rawPhoto.isEmpty ? null : rawPhoto;

                            return UserHeader(
                              name: name,
                              photoUrl: photoUrl,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Comment Box
                      ReviewCommentBox(
                        text: r.commentText,
                        borderColor: primary.withOpacity(0.35),
                      ),

                      if (dateText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          dateText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}