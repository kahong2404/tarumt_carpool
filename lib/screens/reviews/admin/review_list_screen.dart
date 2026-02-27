import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';
import 'package:tarumt_carpool/repositories/review_repository.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/screens/reviews/admin/review_detail_screen.dart';

class AdminReviewListScreen extends StatefulWidget {
  const AdminReviewListScreen({super.key});

  @override
  State<AdminReviewListScreen> createState() => _AdminReviewListScreenState();
}

class _AdminReviewListScreenState extends State<AdminReviewListScreen> {
  static const primary = Color(0xFF1E73FF);

  final _repo = ReviewRepository();

  /// suspicious filter: "all", "sus", "ok"
  String _susFilter = 'all';

  /// star filter: "all", "5", "4", "3", "2", "1"
  String _starFilter = 'all';

  /// sort
  bool _descending = true;

  bool? get _susFilterBool {
    if (_susFilter == 'sus') return true;
    if (_susFilter == 'ok') return false;
    return null;
  }

  int? get _starInt => _starFilter == 'all' ? null : int.tryParse(_starFilter);

  @override
  Widget build(BuildContext context) {
    final stream = _repo.streamAdminReviewsFiltered(
      descending: _descending,
      suspiciousFilter: _susFilterBool,
      star: _starInt,
    );
    return AppScaffold(
      title: 'Review Management',
      child: Column(
        children: [
          _AdminFilterBar(
            suspiciousFilter: _susFilter,
            starFilter: _starFilter,
            descending: _descending,
            onSuspiciousChanged: (v) => setState(() => _susFilter = v),
            onStarChanged: (v) => setState(() => _starFilter = v),
            onSortChanged: (v) => setState(() => _descending = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No reviews found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();

                    final riderId = (data['riderId'] ?? '').toString();
                    final driverId = (data['driverId'] ?? '').toString();
                    final comment = (data['commentText'] ?? '').toString();

                    final rawScore = data['ratingScore'];
                    final score = rawScore is int ? rawScore : (rawScore as num?)?.toInt() ?? 0;

                    final isSuspicious = (data['isSuspicious'] ?? false) == true;

                    final ts = data['createdAt'] as Timestamp?;
                    final dateText = ts == null ? '' : _prettyDate(ts.toDate());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminReviewCard(
                        reviewId: doc.id,
                        riderId: riderId,
                        driverId: driverId,
                        comment: comment,
                        dateText: dateText,
                        isSuspicious: isSuspicious,
                        stars: score,
                        onDetail: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminReviewDetailScreen(reviewId: doc.id),
                            ),
                          );
                        },
                      ),
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

  String _prettyDate(DateTime d) => '${d.day} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}

class _AdminFilterBar extends StatelessWidget {
  final String suspiciousFilter; // all / sus / ok
  final String starFilter;       // all / 5 / 4 / 3 / 2 / 1
  final bool descending;

  final ValueChanged<String> onSuspiciousChanged;
  final ValueChanged<String> onStarChanged;
  final ValueChanged<bool> onSortChanged;

  const _AdminFilterBar({
    required this.suspiciousFilter,
    required this.starFilter,
    required this.descending,
    required this.onSuspiciousChanged,
    required this.onStarChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: suspiciousFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'sus', child: Text('Suspicious')),
                    DropdownMenuItem(value: 'ok', child: Text('No suspicious')),
                  ],
                  onChanged: (v) => onSuspiciousChanged(v ?? 'all'),
                  decoration: const InputDecoration(
                    labelText: 'Suspicious',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  value: descending,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Latest first')),
                    DropdownMenuItem(value: false, child: Text('Oldest first')),
                  ],
                  onChanged: (v) => onSortChanged(v ?? true),
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: starFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All stars')),
              DropdownMenuItem(value: '5', child: Text('5 ★')),
              DropdownMenuItem(value: '4', child: Text('4 ★')),
              DropdownMenuItem(value: '3', child: Text('3 ★')),
              DropdownMenuItem(value: '2', child: Text('2 ★')),
              DropdownMenuItem(value: '1', child: Text('1 ★')),
            ],
            onChanged: (v) => onStarChanged(v ?? 'all'),
            decoration: const InputDecoration(
              labelText: 'Rating',
              filled: true,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReviewCard extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String reviewId;
  final String riderId;
  final String driverId;
  final String comment;
  final String dateText;
  final bool isSuspicious;
  final int stars;
  final VoidCallback onDetail;

  const _AdminReviewCard({
    required this.reviewId,
    required this.riderId,
    required this.driverId,
    required this.comment,
    required this.dateText,
    required this.isSuspicious,
    required this.stars,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final c = comment.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isSuspicious ? Border.all(color: Colors.orange, width: 1.2) : null,
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
                child: _UserNameByIdText(
                  userId: riderId,
                  prefix: '',
                  fallback: 'Unknown rider',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),

              // show stars (or keep single star icon if you prefer)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = (i + 1) <= stars.clamp(0, 5);
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            c.isEmpty ? '-' : c,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  dateText,
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  text: 'Look detail',
                  onPressed: onDetail,
                ),
              ),
            ],
          ),

          if (isSuspicious) ...[
            const SizedBox(height: 8),
            const Text(
              'Suspicious',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserNameByIdText extends StatelessWidget {
  final String userId;
  final String prefix;
  final String fallback;
  final TextStyle style;

  const _UserNameByIdText({
    required this.userId,
    required this.prefix,
    required this.fallback,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return Text('$prefix$fallback', style: style);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Text('$prefix$fallback', style: style);
        }
        final data = snap.data!.data() ?? {};
        final name = (data['name'] ?? fallback).toString();
        return Text(
          '$prefix$name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
