import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/repositories/review_repository.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

import 'package:tarumt_carpool/widgets/reviews/driver_review_filter_bar.dart';
import 'package:tarumt_carpool/widgets/reviews/rating_distribution_row.dart';
import 'package:tarumt_carpool/widgets/reviews/rating_stars_display.dart';

class DriverRatingScreen extends StatefulWidget {
  const DriverRatingScreen({super.key});

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  static const primary = Color(0xFF1E73FF);

  final _auth = FirebaseAuth.instance;
  final _reviewRepo = ReviewRepository();
  final _userRepo = UserRepository();

  String _starFilter = 'all';
  bool _descending = true;

  int? get _starInt => _starFilter == 'all' ? null : int.tryParse(_starFilter);

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    // ✅ Stream A: ALWAYS ALL visible reviews (for summary)
    final summaryStream = _reviewRepo.streamDriverVisibleReviews(uid);

    // ✅ Stream B: Filtered list (for list display)
    final listStream = _reviewRepo.streamDriverVisibleReviewsFiltered(
      driverId: uid,
      star: _starInt,
      descending: _descending,
    );

    // ✅ Stream C: Driver header (name + photo)
    final headerStream = _streamDriverHeader(uid);

    return AppScaffold(
      title: 'My Review',
        child: Column(
          children: [
            DriverReviewFilterBar(
              starFilter: _starFilter,
              descending: _descending,
              onStarChanged: (v) => setState(() => _starFilter = v),
              onSortChanged: (v) => setState(() => _descending = v),
            ),
            Expanded(
              child: StreamBuilder<_DriverHeaderVM>(
                stream: headerStream,
                builder: (context, headerSnap) {
                  final header = headerSnap.data ??
                      const _DriverHeaderVM(name: 'Driver', photoUrl: null);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: summaryStream,
                    builder: (context, summarySnap) {
                      if (summarySnap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Error: ${summarySnap.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!summarySnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final summaryDocs = summarySnap.data!.docs;
                      final summary = _computeSummary(summaryDocs);

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: listStream,
                        builder: (context, listSnap) {
                          if (listSnap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'Error: ${listSnap.error}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          if (!listSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = listSnap.data!.docs;

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                            children: [
                              _SummaryCard(
                                name: header.name,
                                photoUrl: header.photoUrl, // ✅ show pic
                                avg: summary.avg,
                                total: summary.total,
                                counts: summary.counts,
                                barColor: primary,
                              ),
                              const SizedBox(height: 12),
                              if (docs.isEmpty)
                                const _EmptyCard(
                                  'No reviews found for this filter.',
                                )
                              else
                                ...docs.map((doc) {
                                  final data = doc.data();

                                  final rideId =
                                  (data['rideId'] ?? '').toString();
                                  final riderId =
                                  (data['riderId'] ?? '').toString();
                                  final comment =
                                  (data['commentText'] ?? '').toString();

                                  final raw = data['ratingScore'];
                                  final score = raw is int
                                      ? raw
                                      : (raw as num?)?.toInt() ?? 0;

                                  final ts = data['createdAt'] as Timestamp?;
                                  final dateText =
                                  ts == null ? '' : ts.toDate().toString();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ReviewListCard(
                                      rideId: rideId,
                                      riderId: riderId,
                                      stars: score,
                                      comment: comment,
                                      dateText: dateText,
                                    ),
                                  );
                                }),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  /// ✅ Driver header from users/{uid} (name + photoUrl)
  Stream<_DriverHeaderVM> _streamDriverHeader(String uid) {
    return _userRepo.streamUserDoc(uid).map((user) {
      final data = user ?? {};
      final name = (data['name'] ?? 'Driver').toString();
      final photo = (data['photoUrl'] ?? '').toString().trim();
      return _DriverHeaderVM(
        name: name,
        photoUrl: photo.isEmpty ? null : photo,
      );
    });
  }
}

/// --- summary model ---
class _RatingSummary {
  final int total;
  final double avg;
  final Map<int, int> counts; // 1..5
  const _RatingSummary({
    required this.total,
    required this.avg,
    required this.counts,
  });
}

/// ✅ compute summary from ALL reviews (not filtered)
_RatingSummary _computeSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
  final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  var sum = 0;
  var total = 0;

  for (final d in docs) {
    final data = d.data();
    final raw = data['ratingScore'];
    final score = raw is int ? raw : (raw as num?)?.toInt() ?? 0;

    if (score >= 1 && score <= 5) {
      counts[score] = (counts[score] ?? 0) + 1;
      sum += score;
      total++;
    }
  }

  final avg = total == 0 ? 0.0 : (sum / total);
  return _RatingSummary(total: total, avg: avg, counts: counts);
}

class _SummaryCard extends StatelessWidget {
  final String name;
  final String? photoUrl; // ✅ ADD
  final double avg;
  final int total;
  final Map<int, int> counts;
  final Color barColor;

  const _SummaryCard({
    required this.name,
    required this.photoUrl, // ✅ ADD
    required this.avg,
    required this.total,
    required this.counts,
    required this.barColor,
  });

  String _initials(String n) {
    final parts = n
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

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
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.black12,
            backgroundImage: (photoUrl == null) ? null : NetworkImage(photoUrl!),
            child: (photoUrl == null)
                ? Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w900),
            )
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(width: 6),
              RatingStarsDisplay(value: avg, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '($total Ratings)',
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          RatingDistributionRow(
              star: 5, count: counts[5] ?? 0, total: total, barColor: barColor),
          RatingDistributionRow(
              star: 4, count: counts[4] ?? 0, total: total, barColor: barColor),
          RatingDistributionRow(
              star: 3, count: counts[3] ?? 0, total: total, barColor: barColor),
          RatingDistributionRow(
              star: 2, count: counts[2] ?? 0, total: total, barColor: barColor),
          RatingDistributionRow(
              star: 1, count: counts[1] ?? 0, total: total, barColor: barColor),
        ],
      ),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String rideId;
  final String riderId;
  final int stars;
  final String comment;
  final String dateText;

  const _ReviewListCard({
    required this.rideId,
    required this.riderId,
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
          Text('Ride ID: $rideId',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: (riderId.trim().isEmpty)
                ? const Stream.empty()
                : FirebaseFirestore.instance
                .collection('users')
                .doc(riderId)
                .snapshots(),
            builder: (context, snap) {
              if (riderId.trim().isEmpty) {
                return const Text(
                  'Rider: -',
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                );
              }

              if (!snap.hasData || !snap.data!.exists) {
                return const Text(
                  'Rider: ...',
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                );
              }

              final data = snap.data!.data() ?? {};
              final riderName = (data['name'] ?? 'Unknown').toString();

              return Text(
                'Rider: $riderName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
              );
            },
          ),

          const SizedBox(height: 8),
          RatingStarsDisplay(value: stars.toDouble(), size: 18),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.35), width: 1.6),
            ),
            child: Text(c.isEmpty ? '-' : c),
          ),
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

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard(this.text);

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

class _DriverHeaderVM {
  final String name;
  final String? photoUrl;
  const _DriverHeaderVM({required this.name, required this.photoUrl});
}