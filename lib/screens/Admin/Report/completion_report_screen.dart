import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

enum ReportRange { today, last7, last30 }

class CompletionReportScreen extends StatefulWidget {
  const CompletionReportScreen({super.key});

  @override
  State<CompletionReportScreen> createState() => _CompletionReportScreenState();
}

class _CompletionReportScreenState extends State<CompletionReportScreen> {
  static const Color createdColor = Color(0xFF1E73FF);
  static const Color completedColor = Color(0xFF2ECC71);
  static const Color cancelledColor = Color(0xFFFFA000);

  ReportRange _range = ReportRange.last7;

  // ✅ cache future so taps do NOT reload
  late Future<Map<String, int>> _future;

  int _touchedIndex = -1;
  Offset? _tooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _loadCounts(); // initial load
  }

  // ✅ range helpers
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

  // ✅ NEW: chart title like Revenue report
  String _chartTitle(ReportRange r) {
    switch (r) {
      case ReportRange.today:
        return 'Ride Outcomes (today)';
      case ReportRange.last7:
        return 'Ride Outcomes (last 7 days)';
      case ReportRange.last30:
        return 'Ride Outcomes (last 30 days)';
    }
  }

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

  void _reload() {
    setState(() {
      _touchedIndex = -1;
      _tooltipPos = null;
      _future = _loadCounts();
    });
  }

  Future<Map<String, int>> _loadCounts() async {
    final (start, end) = _getRangeWindow(_range);

    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final created = snap.docs.length;
    var completed = 0;
    var cancelled = 0;

    for (final doc in snap.docs) {
      final status = (doc.data()['rideStatus'] ?? '') as String;
      if (status == 'completed') completed++;
      if (status == 'cancelled') cancelled++;
    }

    return {'created': created, 'completed': completed, 'cancelled': cancelled};
  }

  int _maxInt(List<int> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x > y ? x : y);

  int _niceIntervalInt(int maxY) {
    if (maxY <= 5) return 1;
    final raw = (maxY / 5).ceil();
    if (raw <= 2) return 2;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 20) return 20;
    if (raw <= 50) return 50;
    return 100;
  }

  String _label(int x) => switch (x) {
    0 => 'Created',
    1 => 'Completed',
    2 => 'Cancelled',
    _ => 'Unknown',
  };

  Color _color(int x) => switch (x) {
    0 => createdColor,
    1 => completedColor,
    2 => cancelledColor,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final titleText = _chartTitle(_range);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion Report'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<ReportRange>(
              value: _range,
              items: ReportRange.values
                  .map(
                    (r) => DropdownMenuItem(
                  value: r,
                  child: Text(_rangeLabel(r)),
                ),
              )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _range = v);
                _reload(); // ✅ refetch for the new range
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final data =
              snap.data ?? {'created': 0, 'completed': 0, 'cancelled': 0};

          final created = data['created']!;
          final completed = data['completed']!;
          final cancelled = data['cancelled']!;
          final values = [created, completed, cancelled];

          final completionRate = created == 0 ? 0 : (completed / created * 100);
          final cancelRate = created == 0 ? 0 : (cancelled / created * 100);

          final maxCount = _maxInt(values);
          final yMax = (maxCount == 0 ? 1 : (maxCount + 1)).toDouble();
          final interval = _niceIntervalInt(yMax.toInt()).toDouble();

          return Padding(
            padding: ReportUI.pagePadding,
            child: ListView(
              children: [
                ReportInfoBox(
                  title: 'What this report means',
                  body:
                  'Shows how reliable the service is for ${_rangeLabel(_range).toLowerCase()}. '
                      'A high completion rate means rides usually finish successfully. '
                      'A high cancellation rate means users are dropping off and matching/policies may need improvement.',
                ),
                const SizedBox(height: ReportUI.gapM),

                Row(
                  children: [
                    Expanded(
                      child: _RateCard(
                        title: 'Completion Rate',
                        value: '${completionRate.toStringAsFixed(1)}%',
                        subtitle:
                        '$completed rides (completed) / $created rides (created)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RateCard(
                        title: 'Cancellation Rate',
                        value: '${cancelRate.toStringAsFixed(1)}%',
                        subtitle:
                        '$cancelled rides (cancelled) / $created rides (created)',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: ReportUI.gapXL),

                // ✅ NEW: Title like Revenue report (changes by filter)
                Text(
                  titleText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // ✅ Chart with floating tooltip (no Firestore reload on tap)
                ReportChartBox(
                  chart: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          BarChart(
                            BarChartData(
                              minY: 0,
                              maxY: yMax,
                              borderData: FlBorderData(
                                show: true,
                                border: ReportUI.chartBorder,
                              ),
                              gridData: ReportUI.grid(),
                              extraLinesData: ReportUI.baseline0(),
                              barGroups: List.generate(3, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: values[i].toDouble(),
                                      width: 22,
                                      color: _color(i),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                );
                              }),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: ReportUI.leftAxis(
                                  title: 'Number of Rides',
                                  interval: interval,
                                ),
                                bottomTitles: ReportUI.bottomAxis(
                                  title: 'Ride Status',
                                  interval: 1,
                                  getTitle: (value, meta) {
                                    final x = value.toInt();
                                    if (x < 0 || x > 2) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_label(x)),
                                    );
                                  },
                                ),
                              ),

                              // ✅ custom tooltip
                              barTouchData: BarTouchData(
                                enabled: true,
                                handleBuiltInTouches: false,
                                touchCallback: (event, rsp) {
                                  if (rsp == null || rsp.spot == null) {
                                    setState(() {
                                      _touchedIndex = -1;
                                      _tooltipPos = null;
                                    });
                                    return;
                                  }
                                  if (event is! FlTapUpEvent) return;

                                  final idx = rsp.spot!.touchedBarGroup.x;
                                  setState(() {
                                    _touchedIndex = idx;
                                    _tooltipPos = event.localPosition;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (_touchedIndex >= 0 && _tooltipPos != null)
                            Positioned(
                              left: (_tooltipPos!.dx - 95)
                                  .clamp(8.0, box.maxWidth - 190),
                              top: (_tooltipPos!.dy - 80)
                                  .clamp(8.0, box.maxHeight - 90),
                              child: ReportFloatingTooltip(
                                title: _label(_touchedIndex),
                                line2: 'Rides: ${values[_touchedIndex]}',
                                color: _color(_touchedIndex),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // ✅ legend card
                Center(
                  child: SizedBox(
                    width: 220,
                    child: ReportLegendCard(
                      title: 'Ride Status',
                      items: const [
                        ReportLegendItem(color: createdColor, label: 'Created'),
                        ReportLegendItem(color: completedColor, label: 'Completed'),
                        ReportLegendItem(color: cancelledColor, label: 'Cancelled'),
                      ],
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

class _RateCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _RateCard({
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}