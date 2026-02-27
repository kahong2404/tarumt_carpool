import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

class RatingDistributionReportScreen extends StatefulWidget {
  const RatingDistributionReportScreen({super.key});

  @override
  State<RatingDistributionReportScreen> createState() =>
      _RatingDistributionReportScreenState();
}

class _RatingDistributionReportScreenState
    extends State<RatingDistributionReportScreen> {
  // Pie slice colors
  static const Color star1Color = Color(0xFFE53935); // red
  static const Color star2Color = Color(0xFFFF7043); // orange-red
  static const Color star3Color = Color(0xFFFFA000); // orange
  static const Color star4Color = Color(0xFF42A5F5); // blue
  static const Color star5Color = Color(0xFF2ECC71); // green

  late Future<_RatingDistResult> _future;

  int _touchedIndex = -1;
  Offset? _tooltipPos;

  // 🔧 Match DriverFunnel feel: consistent chart/legend spacing
  static const double _chartBoxHeight = 360;
  static const double _legendGap = 50; // 👈 gap between pie and legend

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RatingDistResult> _load() async {
    final snap =
    await FirebaseFirestore.instance.collection('rating_Reviews').get();

    final counts = List<int>.filled(6, 0);

    int totalVisibleActive = 0;
    int sumVisibleActive = 0;

    int suspiciousAll = 0;
    int hiddenOrInactive = 0;

    for (final doc in snap.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final visibility =
      (data['visibility'] ?? '').toString().trim().toLowerCase();

      final isSuspicious = data['isSuspicious'] == true;
      if (isSuspicious) suspiciousAll++;

      final isActiveVisible = (status == 'active' && visibility == 'visible');
      if (!isActiveVisible) {
        hiddenOrInactive++;
        continue;
      }

      final rating = (data['ratingScore'] as num?)?.toInt() ?? 0;
      if (rating < 1 || rating > 5) continue;

      totalVisibleActive++;
      sumVisibleActive += rating;
      counts[rating]++;
    }

    final avg =
    totalVisibleActive <= 0 ? 0.0 : (sumVisibleActive / totalVisibleActive);

    return _RatingDistResult(
      totalVisibleActive: totalVisibleActive,
      avgVisibleActive: avg,
      star1: counts[1],
      star2: counts[2],
      star3: counts[3],
      star4: counts[4],
      star5: counts[5],
      suspiciousAll: suspiciousAll,
      hiddenOrInactive: hiddenOrInactive,
    );
  }

  String _pctStr(int part, int total) {
    if (total <= 0) return '0.0%';
    final v = (part / total) * 100.0;
    return '${v.toStringAsFixed(1)}%';
  }

  Color _colorForStar(int star) {
    switch (star) {
      case 1:
        return star1Color;
      case 2:
        return star2Color;
      case 3:
        return star3Color;
      case 4:
        return star4Color;
      case 5:
        return star5Color;
      default:
        return Colors.grey;
    }
  }

  List<_PieItem> _buildPieItems(_RatingDistResult r) {
    final items = <_PieItem>[];
    final map = <int, int>{
      1: r.star1,
      2: r.star2,
      3: r.star3,
      4: r.star4,
      5: r.star5,
    };

    for (final e in map.entries) {
      if (e.value <= 0) continue;
      items.add(_PieItem(
        stars: e.key,
        count: e.value,
        color: _colorForStar(e.key),
      ));
    }
    return items;
  }

  PieChartSectionData _section({
    required double value,
    required Color color,
    required String label,
    required bool isTouched,
  }) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: isTouched ? 78 : 70,
      title: label,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Offset _calcTooltipPos({
    required Size boxSize,
    required List<_PieItem> items,
    required int touchedIndex,
    required double startAngleDeg,
  }) {
    final total = items.fold<int>(0, (s, it) => s + it.count);
    if (total <= 0) return Offset(boxSize.width / 2, boxSize.height / 2);

    final cx = boxSize.width / 2;
    final cy = boxSize.height / 2;

    final pieRadius = (math.min(boxSize.width, boxSize.height) / 2) - 24;
    final tooltipRadius = pieRadius + 18;

    double start = startAngleDeg * math.pi / 180.0;

    for (int i = 0; i < items.length; i++) {
      final sweep = (items[i].count / total) * 2 * math.pi;

      if (i == touchedIndex) {
        final mid = start + sweep / 2;
        final x = cx + math.cos(mid) * tooltipRadius;
        final y = cy + math.sin(mid) * tooltipRadius;

        return Offset(
          x.clamp(20.0, boxSize.width - 20.0),
          y.clamp(20.0, boxSize.height - 20.0),
        );
      }
      start += sweep;
    }

    return Offset(cx, cy);
  }

  int _filledStars(double avg) => avg.round().clamp(0, 5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ratings Distribution')),
      body: FutureBuilder<_RatingDistResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final r = snap.data ?? _RatingDistResult.empty();
          final total = r.totalVisibleActive;

          final pieItems = _buildPieItems(r);
          final showTooltip =
              _touchedIndex >= 0 && _touchedIndex < pieItems.length;
          final tooltipItem = showTooltip ? pieItems[_touchedIndex] : null;

          return Padding(
            padding: ReportUI.pagePadding,
            child: ListView(
              children: [
                const ReportInfoBox(
                  title: 'What this report means',
                  body:
                  'This report shows the percentage distribution of ratings and the average rating for reviews that are active and visible only, and can be used to evaluate service quality and overall user satisfaction.',
                ),
                const SizedBox(height: ReportUI.gapM),

                // KPI Row 1
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total of Review',
                        value: total.toString(),
                        subtitle: 'Active Visible Reviews',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCardWithStars(
                        title: 'Average Rating',
                        value: total <= 0
                            ? '0.00'
                            : r.avgVisibleActive.toStringAsFixed(2),
                        filledStars:
                        total <= 0 ? 0 : _filledStars(r.avgVisibleActive),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // KPI Row 2

                const SizedBox(height: ReportUI.gapXL),
                const Text(
                  'Ratings (Pie Chart)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),

                // ✅ Same approach as DriverFunnel: one chart box with a stable layout.
                ReportChartBox(
                  chart: SizedBox(
                    height: _chartBoxHeight,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const startAngleDeg = -90.0;

                        // Build legend (same for all)
                        final legend = Center(
                          child: SizedBox(
                            width: 240,
                            child: _LegendStars(
                              items: const [
                                _LegendStarsItem(color: star5Color, stars: 5),
                                _LegendStarsItem(color: star4Color, stars: 4),
                                _LegendStarsItem(color: star3Color, stars: 3),
                                _LegendStarsItem(color: star2Color, stars: 2),
                                _LegendStarsItem(color: star1Color, stars: 1),
                              ],
                            ),
                          ),
                        );

                        // Pie widget
                        final pieWidget = LayoutBuilder(
                          builder: (context, pieBox) {
                            final pieSize =
                            Size(pieBox.maxWidth, pieBox.maxHeight);

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PieChart(
                                  PieChartData(
                                    startDegreeOffset: startAngleDeg,
                                    centerSpaceRadius: 0,
                                    sectionsSpace: 0,
                                    pieTouchData: PieTouchData(
                                      enabled: true,
                                      touchCallback: (event, rsp) {
                                        if (rsp == null ||
                                            rsp.touchedSection == null) {
                                          setState(() {
                                            _touchedIndex = -1;
                                            _tooltipPos = null;
                                          });
                                          return;
                                        }
                                        if (event is! FlTapUpEvent) return;

                                        final idx = rsp.touchedSection!
                                            .touchedSectionIndex;

                                        setState(() {
                                          _touchedIndex = idx;
                                          _tooltipPos = _calcTooltipPos(
                                            boxSize: pieSize,
                                            items: pieItems,
                                            touchedIndex: idx,
                                            startAngleDeg: startAngleDeg,
                                          );
                                        });
                                      },
                                    ),
                                    sections:
                                    List.generate(pieItems.length, (i) {
                                      final it = pieItems[i];
                                      return _section(
                                        value: it.count.toDouble(),
                                        color: it.color,
                                        label: _pctStr(it.count, total),
                                        isTouched: _touchedIndex == i,
                                      );
                                    }),
                                  ),
                                ),
                                if (tooltipItem != null && _tooltipPos != null)
                                  Positioned(
                                    left: _tooltipPos!.dx - 95,
                                    top: _tooltipPos!.dy - 70,
                                    child: _FloatingTooltipStars(
                                      stars: tooltipItem.stars,
                                      count: tooltipItem.count,
                                      pct: _pctStr(tooltipItem.count, total),
                                      color: tooltipItem.color,
                                    ),
                                  ),
                              ],
                            );
                          },
                        );

                        // ✅ Force the SAME look as DriverFunnel: pie on top, legend below with a real gap.
                        return Column(
                          children: [
                            Expanded(child: pieWidget),
                            const SizedBox(height: _legendGap), // ✅ this is your gap
                            legend,
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: ReportUI.gapXL),

              ],
            ),
          );
        },
      ),
    );
  }
}

class _RatingDistResult {
  final int totalVisibleActive;
  final double avgVisibleActive;

  final int star1;
  final int star2;
  final int star3;
  final int star4;
  final int star5;

  final int suspiciousAll;
  final int hiddenOrInactive;

  _RatingDistResult({
    required this.totalVisibleActive,
    required this.avgVisibleActive,
    required this.star1,
    required this.star2,
    required this.star3,
    required this.star4,
    required this.star5,
    required this.suspiciousAll,
    required this.hiddenOrInactive,
  });

  factory _RatingDistResult.empty() => _RatingDistResult(
    totalVisibleActive: 0,
    avgVisibleActive: 0,
    star1: 0,
    star2: 0,
    star3: 0,
    star4: 0,
    star5: 0,
    suspiciousAll: 0,
    hiddenOrInactive: 0,
  );
}

class _PieItem {
  final int stars; // 1..5
  final int count;
  final Color color;

  _PieItem({
    required this.stars,
    required this.count,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ReportUI.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(ReportUI.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value,
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _KpiCardWithStars extends StatelessWidget {
  final String title;
  final String value;
  final int filledStars;

  const _KpiCardWithStars({
    required this.title,
    required this.value,
    required this.filledStars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ReportUI.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(ReportUI.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value,
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final filled = i < filledStars;
              return Icon(
                filled ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FloatingTooltipStars extends StatelessWidget {
  final int stars;
  final int count;
  final String pct;
  final Color color;

  const _FloatingTooltipStars({
    required this.stars,
    required this.count,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4A4A4A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 4),
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      stars,
                          (_) => const Icon(Icons.star,
                          size: 16, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Number of Reviews: $count',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    pct,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendStars extends StatelessWidget {
  final List<_LegendStarsItem> items;
  const _LegendStars({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ratings',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 10),
          for (final it in items) ...[
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: it.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${it.stars}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    it.stars,
                        (_) => const Icon(Icons.star,
                        size: 14, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _LegendStarsItem {
  final Color color;
  final int stars;
  const _LegendStarsItem({required this.color, required this.stars});
}

class _CommentBox extends StatelessWidget {
  final String title;
  final String body;

  const _CommentBox({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ReportUI.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(ReportUI.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}