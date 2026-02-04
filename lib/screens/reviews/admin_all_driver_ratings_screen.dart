import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import 'admin_driver_reviews_screen.dart';

class AdminAllDriverRatingsScreen extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);
  static const bg = Color(0xFFF5F6FA);

  AdminAllDriverRatingsScreen({super.key});

  final _reviewRepo = ReviewRepository();
  final _userRepo = UserRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Driver Ratings'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // ✅ only visible + active used for rating summary
          stream: _reviewRepo.reviews
              .where('status', isEqualTo: 'active')
              .where('visibility', isEqualTo: 'visible')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _EmptyCard('Error: ${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
            }

            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return const _EmptyCard('No driver ratings yet.');
            }

            // Group reviews by driverId
            final Map<String, _Agg> agg = {};
            for (final doc in docs) {
              final d = doc.data();
              final driverId = (d['driverId'] ?? '').toString().trim();
              if (driverId.isEmpty) continue;

              final score = ((d['ratingScore'] ?? 0) as num).toInt().clamp(1, 5);
              agg.putIfAbsent(driverId, () => _Agg());
              agg[driverId]!.add(score);
            }

            final driverIds = agg.keys.toList();

            return FutureBuilder<List<_DriverRowVM>>(
              future: _buildDriverRows(driverIds, agg),
              builder: (context, vmSnap) {
                if (!vmSnap.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                }

                final rows = vmSnap.data!;
                if (rows.isEmpty) {
                  return const _EmptyCard('No driver ratings yet.');
                }

                // sort by avg desc, then count desc
                rows.sort((a, b) {
                  final c1 = b.avg.compareTo(a.avg);
                  if (c1 != 0) return c1;
                  return b.count.compareTo(a.count);
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    const Text(
                      'All Drivers',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    ...rows.map((r) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DriverRatingCard(
                          driverName: r.driverName,
                          driverId: r.driverId,
                          avg: r.avg,
                          count: r.count,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminDriverReviewsScreen(driverId: r.driverId),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<_DriverRowVM>> _buildDriverRows(
      List<String> driverIds,
      Map<String, _Agg> agg,
      ) async {
    // fetch driver names (simple, one by one)
    final out = <_DriverRowVM>[];
    for (final id in driverIds) {
      final user = await _userRepo.getUserDocMap(id);
      final name = (user?['name'] ?? 'Driver').toString();
      final a = agg[id]!;
      out.add(_DriverRowVM(
        driverId: id,
        driverName: name,
        avg: a.avg,
        count: a.count,
      ));
    }
    return out;
  }
}

class _Agg {
  int count = 0;
  int sum = 0;

  void add(int star) {
    count += 1;
    sum += star;
  }

  double get avg => count == 0 ? 0 : (sum / count);
}

class _DriverRowVM {
  final String driverId;
  final String driverName;
  final double avg;
  final int count;

  _DriverRowVM({
    required this.driverId,
    required this.driverName,
    required this.avg,
    required this.count,
  });
}

class _DriverRatingCard extends StatelessWidget {
  static const primary = Color(0xFF1E73FF);

  final String driverName;
  final String driverId;
  final double avg;
  final int count;
  final VoidCallback onTap;

  const _DriverRatingCard({
    required this.driverName,
    required this.driverId,
    required this.avg,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            // left: name + id
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Driver ID: $driverId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text('($count)', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),

            // right: arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: primary.withOpacity(0.20)),
              ),
              child: const Icon(Icons.chevron_right, color: primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Text(text, style: const TextStyle(color: Colors.black54)),
        ),
      ),
    );
  }
}
