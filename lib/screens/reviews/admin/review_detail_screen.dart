import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/repositories/review_repository.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/widgets/danger_button.dart';
import 'package:tarumt_carpool/widgets/reviews/rating_stars_display.dart';
import 'package:tarumt_carpool/screens/reviews/admin/driver_rating_screen.dart';

class AdminReviewDetailScreen extends StatefulWidget {
  final String reviewId;
  const AdminReviewDetailScreen({super.key, required this.reviewId});

  @override
  State<AdminReviewDetailScreen> createState() => _AdminReviewDetailScreenState();
}

class _AdminReviewDetailScreenState extends State<AdminReviewDetailScreen> {
  static const primary = Color(0xFF1E73FF);

  final _repo = ReviewRepository();
  bool _loadingMark = false;
  bool _loadingDelete = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Review Detail',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _repo.streamReviewById(widget.reviewId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Failed to load review'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Review not found'));
          }

          final data = snap.data!.data() ?? {};
          final status = (data['status'] ?? 'active').toString();
          if (status == 'deleted') {
            return const Center(child: Text('This review was deleted.'));
          }

          final driverId = (data['driverId'] ?? '').toString();
          final riderId = (data['riderId'] ?? '').toString();
          final rideId = (data['rideId'] ?? '').toString();
          final comment = (data['commentText'] ?? '').toString();
          final isSuspicious = (data['isSuspicious'] ?? false) == true;

          final raw = data['ratingScore'];
          final stars = raw is int ? raw : (raw as num?)?.toInt() ?? 0;

          final ts = data['createdAt'] as Timestamp?;
          final dateText = ts == null ? '' : _formatTimeThenDate(ts.toDate());

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
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
                    Text(
                      'Ride ID: $rideId',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),

                    _ClickableUserName(
                      label: 'Driver: ',
                      userId: driverId,
                      onTap: driverId.trim().isEmpty
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminDriverRatingScreen(
                              driverId: driverId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _ClickableUserName(
                      label: 'Rider: ',
                      userId: riderId,
                      onTap: null,
                    ),

                    const SizedBox(height: 14),
                    RatingStarsDisplay(value: stars.toDouble(), size: 20),

                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primary.withOpacity(0.35),
                          width: 1.6,
                        ),
                      ),
                      child: Text(comment.trim().isEmpty ? '-' : comment.trim()),
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

                    if (isSuspicious) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Suspicious (under moderation)',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    if (isSuspicious) ...[
                      PrimaryButton(
                        text: 'Change to No Suspicious',
                        loading: _loadingMark,
                        onPressed: _loadingMark
                            ? null
                            : () async {
                          setState(() => _loadingMark = true);
                          try {
                            await _repo.adminMarkNotSuspicious(widget.reviewId);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Marked as not suspicious'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _loadingMark = false);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    DangerButton(
                      text: 'Delete Review',
                      loading: _loadingDelete,
                      onPressed: _loadingDelete
                          ? null
                          : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete review?'),
                            content: const Text(
                              'This will hide the review from everyone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (ok != true) return;

                        setState(() => _loadingDelete = true);
                        try {
                          await _repo.adminDeleteReview(widget.reviewId);
                          if (!mounted) return;

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review deleted')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _loadingDelete = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ 01:35 13 March 2026
  static String _formatTimeThenDate(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString();
    final month = _monthName(dt.month);
    final year = dt.year.toString();
    return '$hh:$mm $day $month $year';
  }

  static String _monthName(int m) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (m < 1 || m > 12) return '-';
    return months[m - 1];
  }
}

class _ClickableUserName extends StatelessWidget {
  final String label;
  final String userId;
  final VoidCallback? onTap;

  const _ClickableUserName({
    required this.label,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return Text('$label-', style: const TextStyle(fontWeight: FontWeight.w800));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name = (data['name'] ?? 'Unknown').toString();

        final text = Text(
          '$label$name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: onTap == null ? Colors.black87 : const Color(0xFF1E73FF),
            decoration: onTap == null ? TextDecoration.none : TextDecoration.underline,
          ),
        );

        if (onTap == null) return text;

        return InkWell(
          onTap: onTap,
          child: text,
        );
      },
    );
  }
}