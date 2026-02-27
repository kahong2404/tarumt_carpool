import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RevenueReportScreen extends StatelessWidget {
  const RevenueReportScreen({super.key});

  Future<_RevenueResult> _loadRevenueLast7Days() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    // ✅ Only "paid" rides (change paymentStatus value if your app uses another word)
    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('rideStatus', isEqualTo: 'completed')
        .where('paymentStatus', isEqualTo: 'released')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    double total = 0;
    int count = 0;

    // Group by full date (year-month-day)
    final Map<DateTime, double> byDate = {};

    for (final doc in snap.docs) {
      final data = doc.data();

      final fareNum = data['finalFare'];
      final fare = (fareNum is num) ? fareNum.toDouble() : 0.0;

      final ts = data['completedAt'] as Timestamp?;
      if (ts == null) continue;

      final dt = ts.toDate().toLocal();
      final dayKey = DateTime(dt.year, dt.month, dt.day);

      total += fare;
      count++;

      byDate[dayKey] = (byDate[dayKey] ?? 0) + fare;
    }

    final dates = byDate.keys.toList()..sort();
    final values = dates.map((d) => byDate[d] ?? 0).toList();

    return _RevenueResult(
      total: total,
      count: count,
      dates: dates,
      values: values,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue Report')),
      body: FutureBuilder<_RevenueResult>(
        future: _loadRevenueLast7Days(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final res = snap.data ?? _RevenueResult.empty();
          final avg = res.count == 0 ? 0 : res.total / res.count;

          final maxY = res.values.isEmpty
              ? 1.0
              : (res.values.reduce((a, b) => a > b ? a : b) + 1);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _InfoBox(
                  title: 'What this report means',
                  body:
                  'This report shows revenue from completed rides with payment status “released”. '
                      'Use it to track income trends and see which days are strongest for business.',
                ),
                const SizedBox(height: 12),

                Text('Total Revenue: RM ${res.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Average Fare: RM ${avg.toStringAsFixed(2)}'),
                Text('Paid Completed Rides: ${res.count}'),
                const SizedBox(height: 16),

                SizedBox(
                  height: 280,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: List.generate(res.values.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [BarChartRodData(toY: res.values[i], width: 12)],
                        );
                      }),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= res.dates.length) return const SizedBox.shrink();
                              final d = res.dates[i];
                              // show as MM/DD
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 10)),
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
                            final d = res.dates[group.x];
                            return BarTooltipItem(
                              '${d.year}-${d.month}-${d.day}\nRM ${rod.toY.toStringAsFixed(2)}',
                              const TextStyle(),
                            );
                          },
                        ),
                      ),
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

class _RevenueResult {
  final double total;
  final int count;
  final List<DateTime> dates;
  final List<double> values;

  _RevenueResult({
    required this.total,
    required this.count,
    required this.dates,
    required this.values,
  });

  factory _RevenueResult.empty() => _RevenueResult(total: 0, count: 0, dates: [], values: []);
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String body;

  const _InfoBox({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }
}