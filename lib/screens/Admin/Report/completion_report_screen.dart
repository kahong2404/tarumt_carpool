import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CompletionReportScreen extends StatelessWidget {
  const CompletionReportScreen({super.key});

  Future<Map<String, int>> _loadCounts() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    int created = snap.docs.length;
    int completed = 0;
    int cancelled = 0;

    for (var doc in snap.docs) {
      final status = doc['rideStatus'];
      if (status == 'completed') completed++;
      if (status == 'cancelled') cancelled++;
    }

    return {
      'created': created,
      'completed': completed,
      'cancelled': cancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completion Report')),
      body: FutureBuilder<Map<String, int>>(
        future: _loadCounts(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;
          final created = data['created']!;
          final completed = data['completed']!;
          final cancelled = data['cancelled']!;

          final completionRate =
          created == 0 ? 0 : (completed / created * 100);
          final cancelRate =
          created == 0 ? 0 : (cancelled / created * 100);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                    'Completion Rate: ${completionRate.toStringAsFixed(1)}%'),
                Text('Cancellation Rate: ${cancelRate.toStringAsFixed(1)}%'),
                const SizedBox(height: 20),

                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [
                          BarChartRodData(toY: created.toDouble())
                        ]),
                        BarChartGroupData(x: 1, barRods: [
                          BarChartRodData(toY: completed.toDouble())
                        ]),
                        BarChartGroupData(x: 2, barRods: [
                          BarChartRodData(toY: cancelled.toDouble())
                        ]),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              switch (v.toInt()) {
                                case 0:
                                  return const Text('Created');
                                case 1:
                                  return const Text('Completed');
                                case 2:
                                  return const Text('Cancelled');
                              }
                              return const Text('');
                            },
                          ),
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