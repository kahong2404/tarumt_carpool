import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum ReportRange { today, last7, last30 }

class PeakHourCreatedCompletedReportScreen extends StatefulWidget {
  const PeakHourCreatedCompletedReportScreen({super.key});

  @override
  State<PeakHourCreatedCompletedReportScreen> createState() =>
      _PeakHourCreatedCompletedReportScreenState();
}

class _PeakHourCreatedCompletedReportScreenState
    extends State<PeakHourCreatedCompletedReportScreen> {
  ReportRange _range = ReportRange.last7;

  /// Returns (start, end) in local time
  (DateTime start, DateTime end) _getRangeWindow(ReportRange r) {
    final now = DateTime.now();
    switch (r) {
      case ReportRange.today:
        final startOfDay = DateTime(now.year, now.month, now.day);
        return (startOfDay, now);
      case ReportRange.last7:
        return (now.subtract(const Duration(days: 7)), now);
      case ReportRange.last30:
        return (now.subtract(const Duration(days: 30)), now);
    }
  }

  String _rangeLabel(ReportRange r) {
    switch (r) {
      case ReportRange.today:
        return 'Today';
      case ReportRange.last7:
        return 'Last 7 days';
      case ReportRange.last30:
        return 'Last 30 days';
    }
  }

  Future<({List<int> created, List<int> completed})> _loadCounts() async {
    final (start, end) = _getRangeWindow(_range);

    // 1) Created rides (demand)
    final createdSnap = await FirebaseFirestore.instance
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    // 2) Completed rides (fulfilled supply)
    final completedSnap = await FirebaseFirestore.instance
        .collection('rides')
        .where('rideStatus', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final created = List<int>.filled(24, 0);
    final completed = List<int>.filled(24, 0);

    for (final doc in createdSnap.docs) {
      final data = doc.data();
      final ts = data['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate().toLocal();
      created[dt.hour] += 1;
    }

    for (final doc in completedSnap.docs) {
      final data = doc.data();
      final ts = data['completedAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate().toLocal();
      completed[dt.hour] += 1;
    }

    return (created: created, completed: completed);
  }

  int _maxInt(List<int> a) => a.isEmpty ? 0 : a.reduce((x, y) => x > y ? x : y);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peak Hour Report'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<ReportRange>(
              value: _range,
              items: ReportRange.values.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(_rangeLabel(r)),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _range = v);
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<({List<int> created, List<int> completed})>(
        future: _loadCounts(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final created = snap.data?.created ?? List<int>.filled(24, 0);
          final completed = snap.data?.completed ?? List<int>.filled(24, 0);

          final peakCreatedVal = _maxInt(created);
          final peakCompletedVal = _maxInt(completed);
          final peakCreatedHour = created.indexOf(peakCreatedVal);
          final peakCompletedHour = completed.indexOf(peakCompletedVal);

          final maxY = _maxInt([
            ...created,
            ...completed,
          ]);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                // KPI summary
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiCard(
                      title: 'Peak Created Hour',
                      value: '$peakCreatedHour:00',
                      subtitle: '$peakCreatedVal rides',
                    ),
                    _KpiCard(
                      title: 'Peak Completed Hour',
                      value: '$peakCompletedHour:00',
                      subtitle: '$peakCompletedVal rides',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Created vs Completed per Hour (0–23)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 340,
                  child: BarChart(
                    BarChartData(
                      maxY: (maxY == 0 ? 1 : maxY + 1).toDouble(),
                      barGroups: List.generate(24, (hour) {
                        return BarChartGroupData(
                          x: hour,
                          barsSpace: 4,
                          barRods: [
                            // Created
                            BarChartRodData(
                              toY: created[hour].toDouble(),
                              width: 7,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            // Completed
                            BarChartRodData(
                              toY: completed[hour].toDouble(),
                              width: 7,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 3,
                            getTitlesWidget: (value, meta) {
                              final h = value.toInt();
                              if (h < 0 || h > 23) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('$h'),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final hour = group.x;
                            final isCreated = rodIndex == 0;
                            final label = isCreated ? 'Created' : 'Completed';
                            final value = rod.toY.toInt();
                            return BarTooltipItem(
                              '$hour:00\n$label: $value',
                              const TextStyle(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Tip: If bars look the same style, you can add a legend using small labels below.',
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    _LegendDot(label: 'Created', isSecond: false),
                    SizedBox(width: 16),
                    _LegendDot(label: 'Completed', isSecond: true),
                  ],
                ),
              ],
            ),
          );
        },
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
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final bool isSecond;

  const _LegendDot({required this.label, required this.isSecond});

  @override
  Widget build(BuildContext context) {
    // We’re not setting colors explicitly as you didn’t ask;
    // legend is just label-based.
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}