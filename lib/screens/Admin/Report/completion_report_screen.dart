import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CompletionReportScreen extends StatelessWidget {
  const CompletionReportScreen({super.key});

  Future<Map<String, int>> _loadCountsLast7Days() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    int created = snap.docs.length;
    int completed = 0;
    int cancelled = 0;

    for (final doc in snap.docs) {
      final status = (doc.data()['rideStatus'] ?? '') as String;
      if (status == 'completed') completed++;
      if (status == 'cancelled') cancelled++;
    }

    return {'created': created, 'completed': completed, 'cancelled': cancelled};
  }

  int _maxInt(List<int> a) => a.reduce((x, y) => x > y ? x : y);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completion Report')),
      body: FutureBuilder<Map<String, int>>(
        future: _loadCountsLast7Days(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final data = snap.data ?? {'created': 0, 'completed': 0, 'cancelled': 0};
          final created = data['created']!;
          final completed = data['completed']!;
          final cancelled = data['cancelled']!;

          final completionRate = created == 0 ? 0 : (completed / created * 100);
          final cancelRate = created == 0 ? 0 : (cancelled / created * 100);

          final maxY = _maxInt([created, completed, cancelled]);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _InfoBox(
                  title: 'What this report means',
                  body:
                  'Shows how reliable the service is. A high completion rate means rides usually finish successfully. '
                      'A high cancellation rate means users are dropping off and matching/policies may need improvement.',
                ),
                const SizedBox(height: 12),

                Text('Completion Rate: ${completionRate.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Cancellation Rate: ${cancelRate.toStringAsFixed(1)}%'),
                const SizedBox(height: 16),

                SizedBox(
                  height: 280,
                  child: BarChart(
                    BarChartData(
                      maxY: (maxY == 0 ? 1 : maxY + 1).toDouble(),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: created.toDouble(), width: 22)]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: completed.toDouble(), width: 22)]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: cancelled.toDouble(), width: 22)]),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text('Created'),
                                  );
                                case 1:
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text('Completed'),
                                  );
                                case 2:
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text('Cancelled'),
                                  );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
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