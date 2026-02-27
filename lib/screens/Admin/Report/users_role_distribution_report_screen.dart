import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

class UsersRoleDistributionReportScreen extends StatefulWidget {
  const UsersRoleDistributionReportScreen({super.key});

  @override
  State<UsersRoleDistributionReportScreen> createState() =>
      _UsersRoleDistributionReportScreenState();
}

class _UsersRoleDistributionReportScreenState
    extends State<UsersRoleDistributionReportScreen> {
  static const Color riderOnlyColor = Color(0xFF1E73FF); // blue
  static const Color driverOnlyColor = Color(0xFF2ECC71); // green
  static const Color dualRoleColor = Color(0xFFFFA000); // orange

  // ✅ Cache Firestore future so tapping does NOT reload data
  late Future<_RoleDistResult> _future;

  int _touchedIndex = -1;
  Offset? _tooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RoleDistResult> _load() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();

    int riderOnly = 0;
    int driverOnly = 0;
    int dualRole = 0;

    for (final doc in snap.docs) {
      final data = doc.data();

      final rolesRaw = data['roles'];
      final activeRole =
      (data['activeRole'] ?? '').toString().trim().toLowerCase();

      final roles = <String>{
        if (rolesRaw is List)
          for (final r in rolesRaw) r.toString().trim().toLowerCase(),
      };

      // exclude admin
      if (roles.contains('admin') || activeRole == 'admin') continue;

      final hasRider = roles.contains('rider');
      final hasDriver = roles.contains('driver');

      if (hasRider && hasDriver) {
        dualRole++;
      } else if (hasRider) {
        riderOnly++;
      } else if (hasDriver) {
        driverOnly++;
      }
    }

    return _RoleDistResult(
      riderOnly: riderOnly,
      driverOnly: driverOnly,
      dualRole: dualRole,
    );
  }

  int _total(_RoleDistResult r) => r.riderOnly + r.driverOnly + r.dualRole;

  String _pctStr(int part, int total) {
    if (total <= 0) return '0.0%';
    final v = (part / total) * 100.0;
    return '${v.toStringAsFixed(1)}%';
  }

  // ✅ Only build non-zero slices (prevents wrong touched index)
  List<_PieItem> _buildPieItems(_RoleDistResult res) {
    final items = <_PieItem>[];

    if (res.riderOnly > 0) {
      items.add(_PieItem(
        key: 'rider',
        title: 'Rider only',
        count: res.riderOnly,
        color: riderOnlyColor,
      ));
    }
    if (res.driverOnly > 0) {
      items.add(_PieItem(
        key: 'driver',
        title: 'Driver only',
        count: res.driverOnly,
        color: driverOnlyColor,
      ));
    }
    if (res.dualRole > 0) {
      items.add(_PieItem(
        key: 'dual',
        title: 'Dual role',
        count: res.dualRole,
        color: dualRoleColor,
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
      appBar: AppBar(title: const Text('Users Role Distribution')),
      body: FutureBuilder<_RoleDistResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final res = snap.data ?? _RoleDistResult.empty();
          final total = _total(res);

          final pieItems = _buildPieItems(res);

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
                  'This report shows the distribution of user roles: Rider only, Driver only, and Dual role (both). Use it to analyze platform balance, user engagement, and support strategic decision-making. '
                      ,
                ),
                const SizedBox(height: ReportUI.gapM),

                // ✅ KPI: 2 columns / row
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total Users',
                        value: total.toString(),
                        subtitle: '100%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Rider Only',
                        value: res.riderOnly.toString(),
                        subtitle: _pctStr(res.riderOnly, total),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Driver Only',
                        value: res.driverOnly.toString(),
                        subtitle: _pctStr(res.driverOnly, total),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Dual Role',
                        value: res.dualRole.toString(),
                        subtitle: _pctStr(res.dualRole, total),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: ReportUI.gapXL),
                const Text(
                  'User Role Distribution',
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
                                    sections: List.generate(pieItems.length, (i) {
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
                                    left: _tooltipPos!.dx - 90,
                                    top: _tooltipPos!.dy - 60,
                                    child: _FloatingTooltip(
                                      title: tooltipItem.title,
                                      users: tooltipItem.count,
                                      pct: _pctStr(tooltipItem.count, total),
                                      color: tooltipItem.color,
                                    ),
                                  ),
                              ],
                            );
                          },
                        );

                        // ✅ Legend: shrink-to-fit + centered (no big empty right space)
                        final legend = Center(
                          child: SizedBox(
                            width: 200, // 👈 adjust this (300–360 looks nice)
                            child: _Legend(
                              items: [
                                _LegendItem(color: riderOnlyColor, label: 'Rider only'),
                                _LegendItem(color: driverOnlyColor, label: 'Driver only'),
                                _LegendItem(color: dualRoleColor, label: 'Dual role'),
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
                            // instead of fixed 160 width that creates empty space,
                            // we let legend take only what it needs:
                            SizedBox(
                              width: 220,
                              child: legend,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoleDistResult {
  final int riderOnly;
  final int driverOnly;
  final int dualRole;

  _RoleDistResult({
    required this.riderOnly,
    required this.driverOnly,
    required this.dualRole,
  });

  factory _RoleDistResult.empty() => _RoleDistResult(
    riderOnly: 0,
    driverOnly: 0,
    dualRole: 0,
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
                '$title\nUsers: $users\n$pct',
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
        mainAxisSize: MainAxisSize.min, // ✅ shrink height to content
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Roles',
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