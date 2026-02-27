import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

class DriverVerificationFunnelReportScreen extends StatefulWidget {
  const DriverVerificationFunnelReportScreen({super.key});

  @override
  State<DriverVerificationFunnelReportScreen> createState() =>
      _DriverVerificationFunnelReportScreenState();
}

class _DriverVerificationFunnelReportScreenState
    extends State<DriverVerificationFunnelReportScreen> {
  static const Color notAppliedColor = Color(0xFF9E9E9E); // grey
  static const Color pendingColor = Color(0xFFFFA000); // orange
  static const Color approvedColor = Color(0xFF2ECC71); // green
  static const Color rejectedColor = Color(0xFFE53935); // red

  late Future<_DvFunnelResult> _future;

  int _touchedIndex = -1;
  Offset? _tooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DvFunnelResult> _load() async {
    final fs = FirebaseFirestore.instance;

    // 1) Load users, detect who are drivers (exclude admin)
    final usersSnap = await fs.collection('users').get();

    final driverUserIds = <String>{};

    for (final doc in usersSnap.docs) {
      final data = doc.data();

      final rolesRaw = data['roles'];
      final activeRole = (data['activeRole'] ?? '').toString().trim().toLowerCase();

      final roles = <String>{
        if (rolesRaw is List)
          for (final r in rolesRaw) r.toString().trim().toLowerCase(),
      };

      // exclude admin users
      if (roles.contains('admin') || activeRole == 'admin') continue;

      final isDriver = roles.contains('driver') || activeRole == 'driver';
      if (!isDriver) continue;

      // Your driver verifications doc id is userId (e.g., "2314522")
      // If your user document id is also that, doc.id is OK.
      // If your userId is stored in field "userId", prefer that.
      final userId = (data['userId'] ?? doc.id).toString();
      if (userId.isNotEmpty) driverUserIds.add(userId);
    }

    // 2) Load driver_verifications docs once, map by docId (userId)
    final verSnap = await fs.collection('driver_verifications').get();

    final verByUserId = <String, Map<String, dynamic>>{};
    for (final d in verSnap.docs) {
      verByUserId[d.id] = d.data();
    }

    // 3) Count statuses among drivers only
    int totalDrivers = driverUserIds.length;
    int notApplied = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final userId in driverUserIds) {
      final data = verByUserId[userId];

      // no verification doc => not applied
      if (data == null) {
        notApplied++;
        continue;
      }

      final ver = Map<String, dynamic>.from(data['verification'] ?? {});
      final status = (ver['status'] ?? 'pending').toString().trim().toLowerCase();

      if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        // treat anything else as pending
        pending++;
      }
    }

    return _DvFunnelResult(
      totalDrivers: totalDrivers,
      notApplied: notApplied,
      pending: pending,
      approved: approved,
      rejected: rejected,
    );
  }

  String _pctStr(double v) => '${(v * 100).toStringAsFixed(1)}%';

  double _safeRate(int num, int den) => den <= 0 ? 0.0 : (num / den);

  List<_PieItem> _buildPieItems(_DvFunnelResult r) {
    final items = <_PieItem>[];

    if (r.notApplied > 0) {
      items.add(_PieItem(
        key: 'not_applied',
        title: 'Not applied',
        count: r.notApplied,
        color: notAppliedColor,
      ));
    }
    if (r.pending > 0) {
      items.add(_PieItem(
        key: 'pending',
        title: 'Pending',
        count: r.pending,
        color: pendingColor,
      ));
    }
    if (r.approved > 0) {
      items.add(_PieItem(
        key: 'approved',
        title: 'Approved',
        count: r.approved,
        color: approvedColor,
      ));
    }
    if (r.rejected > 0) {
      items.add(_PieItem(
        key: 'rejected',
        title: 'Rejected',
        count: r.rejected,
        color: rejectedColor,
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

        final clampedX = x.clamp(20.0, boxSize.width - 20.0);
        final clampedY = y.clamp(20.0, boxSize.height - 20.0);

        return Offset(clampedX, clampedY);
      }

      start += sweep;
    }

    return Offset(cx, cy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Verification Funnel')),
      body: FutureBuilder<_DvFunnelResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final r = snap.data ?? _DvFunnelResult.empty();

          final submitted = r.submitted;
          final processed = r.processed;

          final approvalRate = _safeRate(r.approved, processed);
          final rejectionRate = _safeRate(r.rejected, processed);
          final pendingRate = _safeRate(r.pending, submitted);

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
                  'This report shows the driver verification pipeline health: '
                      'how many drivers have not applied, are pending, approved, or rejected. '
                      'It also shows approval, rejection rates ,and pending rate. Use it to monitor verification efficiency and support process improvement',
                ),
                const SizedBox(height: ReportUI.gapM),

                // KPI Row 1
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total Drivers',
                        value: r.totalDrivers.toString(),
                        subtitle: 'Excluded: admin',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Not Applied',
                        value: r.notApplied.toString(),
                        subtitle: r.totalDrivers <= 0
                            ? '0.0%'
                            : _pctStr(r.notApplied / r.totalDrivers),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // KPI Row 2
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Pending',
                        value: r.pending.toString(),
                        subtitle: submitted <= 0 ? '0.0%' : _pctStr(pendingRate),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Approved',
                        value: r.approved.toString(),
                        subtitle: processed <= 0 ? '0.0%' : _pctStr(approvalRate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // KPI Row 3
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Rejected',
                        value: r.rejected.toString(),
                        subtitle: processed <= 0 ? '0.0%' : _pctStr(rejectionRate),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    // const SizedBox(width: 12),
                    // Expanded(
                    //   child: _KpiCard(
                    //     title: 'Submitted Total',
                    //     value: submitted.toString(),
                    //     subtitle: 'Pending + Approved + Rejected',
                    //   ),
                    // ),
                  ],
                ),


                const SizedBox(height: ReportUI.gapXL),
                const Text(
                  'Driver Verification Status Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                ReportChartBox(
                  chart: SizedBox(
                    height: 360,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final isNarrow = c.maxWidth < 360;
                        const startAngleDeg = -90.0;

                        final pie = LayoutBuilder(
                          builder: (context, pieBox) {
                            final pieSize = Size(pieBox.maxWidth, pieBox.maxHeight);

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
                                        if (rsp == null || rsp.touchedSection == null) {
                                          setState(() {
                                            _touchedIndex = -1;
                                            _tooltipPos = null;
                                          });
                                          return;
                                        }

                                        if (event is! FlTapUpEvent) return;

                                        final idx = rsp.touchedSection!.touchedSectionIndex;

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
                                    sections: List.generate(pieItems.length, (i) {
                                      final it = pieItems[i];
                                      final totalForPie = r.totalDrivers <= 0 ? 1 : r.totalDrivers;
                                      final pct = it.count / totalForPie;

                                      return _section(
                                        value: it.count.toDouble(),
                                        color: it.color,
                                        label: _pctStr(pct),
                                        isTouched: _touchedIndex == i,
                                      );
                                    }),
                                  ),
                                ),
                                if (tooltipItem != null && _tooltipPos != null)
                                  Positioned(
                                    left: _tooltipPos!.dx - 90,
                                    top: _tooltipPos!.dy - 60,
                                    child: _FloatingTooltip(
                                      title: tooltipItem.title,
                                      users: tooltipItem.count,
                                      pct: r.totalDrivers <= 0
                                          ? '0.0%'
                                          : _pctStr(tooltipItem.count / r.totalDrivers),
                                      color: tooltipItem.color,
                                    ),
                                  ),
                              ],
                            );
                          },
                        );

                        final legend = Center(
                          child: SizedBox(
                            width: 230,
                            child: _Legend(
                              items: const [
                                _LegendItem(color: notAppliedColor, label: 'Not applied'),
                                _LegendItem(color: pendingColor, label: 'Pending'),
                                _LegendItem(color: approvedColor, label: 'Approved'),
                                _LegendItem(color: rejectedColor, label: 'Rejected'),
                              ],
                            ),
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              Expanded(child: pie),
                              const SizedBox(height: 10),
                              legend,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: pie),
                            const SizedBox(width: 12),
                            SizedBox(width: 240, child: legend),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: ReportUI.gapXL),
                // const Text(
                //   'Rates Explanation',
                //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 8),
                // _RatesCard(
                //   approvalRate: approvalRate,
                //   rejectionRate: rejectionRate,
                //   pendingRate: pendingRate,
                //   processed: processed,
                //   submitted: submitted,
                // ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DvFunnelResult {
  final int totalDrivers;
  final int notApplied;
  final int pending;
  final int approved;
  final int rejected;

  _DvFunnelResult({
    required this.totalDrivers,
    required this.notApplied,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  int get submitted => pending + approved + rejected;
  int get processed => approved + rejected;

  factory _DvFunnelResult.empty() => _DvFunnelResult(
    totalDrivers: 0,
    notApplied: 0,
    pending: 0,
    approved: 0,
    rejected: 0,
  );
}

class _PieItem {
  final String key;
  final String title;
  final int count;
  final Color color;

  _PieItem({
    required this.key,
    required this.title,
    required this.count,
    required this.color,
  });
}

class _RatesCard extends StatelessWidget {
  final double approvalRate;
  final double rejectionRate;
  final double pendingRate;
  final int processed;
  final int submitted;

  const _RatesCard({
    required this.approvalRate,
    required this.rejectionRate,
    required this.pendingRate,
    required this.processed,
    required this.submitted,
  });

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

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
          Text('Approval rate: ${_pct(approvalRate)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Rejection rate: ${_pct(rejectionRate)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Pending rate: ${_pct(pendingRate)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Approval/Rejection rates are based on processed applications only: processed = approved + rejected = $processed.\n'
                'Pending rate is based on submitted: submitted = pending + approved + rejected = $submitted.',
            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _FloatingTooltip extends StatelessWidget {
  final String title;
  final int users;
  final String pct;
  final Color color;

  const _FloatingTooltip({
    required this.title,
    required this.users,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
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
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title\nDrivers: $users\n$pct',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<_LegendItem> items;
  const _Legend({required this.items});

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
          const Text('Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 10),
          for (final it in items) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: it.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(it.label, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
}