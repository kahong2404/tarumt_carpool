import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RevenueReportScreen extends StatelessWidget {
  const RevenueReportScreen({super.key});

  Future<Map<String, dynamic>> _loadRevenue() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('rideStatus', isEqualTo: 'completed')
        .where('completedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    double total = 0;
    Map<int, double> revenueByDay = {};

    for (var doc in snap.docs) {
      final fare = (doc['finalFare'] ?? 0).toDouble();
      total += fare;

      final completedAt =
      (doc['completedAt'] as Timestamp).toDate().toLocal();
      final day = completedAt.day;

      revenueByDay[day] = (revenueByDay[day] ?? 0) + fare;
    }

    return {
      'total': total,
      'count': snap.docs.length,
      'daily': revenueByDay,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue Report')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadRevenue(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final total = snap.data!['total'];
          final count = snap.data!['count'];
          final avg = count == 0 ? 0 : total / count;
          final daily = snap.data!['daily'] as Map<int, double>;

          final spots = daily.entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(toY: e.value),
              ],
            );
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Revenue: RM ${total.toStringAsFixed(2)}'),
                Text('Average Fare: RM ${avg.toStringAsFixed(2)}'),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: spots,
                      titlesData: const FlTitlesData(),
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