import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

enum ReportRange { today, last7, last30 }

class PeakHourCreatedCompletedReportScreen extends StatefulWidget {
  const PeakHourCreatedCompletedReportScreen({super.key});

  @override
  State<PeakHourCreatedCompletedReportScreen> createState() =>
      _PeakHourCreatedCompletedReportScreenState();
}

class _PeakHourCreatedCompletedReportScreenState
    extends State<PeakHourCreatedCompletedReportScreen> {
  static const Color createdColor = Color(0xFF1E73FF); // blue
  static const Color completedColor = Color(0xFF2ECC71); // green

  ReportRange _range = ReportRange.last7;

  // ✅ cache future (avoid refresh on tap)
  late Future<({List<int> created, List<int> completed})> _future;

  // ✅ touched tooltip state (2 charts)
  int _touchedCreatedHour = -1;
  Offset? _createdTooltipPos;

  int _touchedCompletedHour = -1;
  Offset? _completedTooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _loadCounts(); // initial load
  }

  void _reload() {
    setState(() {
      _touchedCreatedHour = -1;
      _createdTooltipPos = null;
      _touchedCompletedHour = -1;
      _completedTooltipPos = null;
      _future = _loadCounts();
    });
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

    final createdSnap = await FirebaseFirestore.instance
        .collection('rides')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final completedSnap = await FirebaseFirestore.instance
        .collection('rides')
        .where('rideStatus', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final created = List<int>.filled(24, 0);
    final completed = List<int>.filled(24, 0);

    for (final doc in createdSnap.docs) {
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate().toLocal();
      created[dt.hour] += 1;
    }

    for (final doc in completedSnap.docs) {
      final ts = doc.data()['completedAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate().toLocal();
      completed[dt.hour] += 1;
    }

    return (created: created, completed: completed);
  }

  int _maxInt(List<int> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x > y ? x : y);

  int _niceInterval(int maxY) {
    if (maxY <= 5) return 1;
    final raw = (maxY / 5).ceil();
    if (raw <= 2) return 2;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 20) return 20;
    if (raw <= 50) return 50;
    return 100;
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendCard({required List<Widget> items}) {
    return Center(
      child: Container(
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
            const Text(
              'Legend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...items.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: w,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChart({
    required String title,
    required String subtitle,
    required List<int> data,
    required Color color,
    required bool isCreatedChart,
  }) {
    final maxCount = _maxInt(data);
    final yMaxInt = (maxCount == 0 ? 1 : maxCount + 1);
    final interval = _niceInterval(yMaxInt).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 10),

        // ✅ chart + floating tooltip
        ReportChartBox(
          chart: LayoutBuilder(
            builder: (context, box) {
              final touchedHour =
              isCreatedChart ? _touchedCreatedHour : _touchedCompletedHour;
              final tooltipPos =
              isCreatedChart ? _createdTooltipPos : _completedTooltipPos;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: yMaxInt.toDouble(),
                      borderData:
                      FlBorderData(show: true, border: ReportUI.chartBorder),
                      gridData: ReportUI.grid(),
                      extraLinesData: ReportUI.baseline0(),

                      barGroups: List.generate(24, (hour) {
                        return BarChartGroupData(
                          x: hour,
                          barRods: [
                            BarChartRodData(
                              toY: data[hour].toDouble(),
                              width: 6,
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }),

                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: ReportUI.leftAxis(
                          title: 'Number of Rides',
                          interval: interval,
                        ),
                        bottomTitles: ReportUI.bottomAxis(
                          title: 'Hour (0:00 to 23:59)',
                          interval: 3,
                          getTitle: (value, meta) {
                            final h = value.toInt();
                            if (h < 0 || h > 23) return const SizedBox.shrink();
                            if (h % 3 != 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('$h', style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),

                      // ✅ tap detection (NO rebuild Firestore)
                      barTouchData: BarTouchData(
                        enabled: true,
                        handleBuiltInTouches: false,
                        touchCallback: (event, rsp) {
                          if (rsp == null || rsp.spot == null) {
                            setState(() {
                              if (isCreatedChart) {
                                _touchedCreatedHour = -1;
                                _createdTooltipPos = null;
                              } else {
                                _touchedCompletedHour = -1;
                                _completedTooltipPos = null;
                              }
                            });
                            return;
                          }

                          if (event is! FlTapUpEvent) return;

                          final hour = rsp.spot!.touchedBarGroup.x;
                          setState(() {
                            if (isCreatedChart) {
                              _touchedCreatedHour = hour;
                              _createdTooltipPos = event.localPosition;
                            } else {
                              _touchedCompletedHour = hour;
                              _completedTooltipPos = event.localPosition;
                            }
                          });
                        },
                      ),
                    ),
                  ),

                  if (touchedHour >= 0 && tooltipPos != null)
                    Positioned(
                      left: (tooltipPos.dx - 95).clamp(8.0, box.maxWidth - 190),
                      top: (tooltipPos.dy - 80).clamp(8.0, box.maxHeight - 90),
                      child: ReportFloatingTooltip(
                        title: '$touchedHour:00 - $touchedHour:59',
                        line2: '${data[touchedHour]} rides',
                        color: color,
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // ✅ legend card
        _legendCard(
          items: [
            _buildLegend(color: color, label: isCreatedChart ? 'Created rides' : 'Completed rides'),
          ],
        ),

        const SizedBox(height: ReportUI.gapXL),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peak Hour Report'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<ReportRange>(
              value: _range,
              items: ReportRange.values
                  .map((r) => DropdownMenuItem(
                value: r,
                child: Text(_rangeLabel(r)),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _range = v);
                _reload(); // ✅ reload when range changed
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<({List<int> created, List<int> completed})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final created = snap.data?.created ?? List<int>.filled(24, 0);
          final completed = snap.data?.completed ?? List<int>.filled(24, 0);

          final peakCreatedVal = _maxInt(created);
          final peakCompletedVal = _maxInt(completed);
          final peakCreatedHour = created.indexOf(peakCreatedVal);
          final peakCompletedHour = completed.indexOf(peakCompletedVal);

          return Padding(
            padding: ReportUI.pagePadding,
            child: ListView(
              children: [
                const ReportInfoBox(
                  title: 'What this report shows',
                  body:
                  'This report breaks down activity by hour (0:00 to 23:59). '
                      'Created rides show demand. Completed rides show fulfilled trips. '
                      'Admins can identify peak hours to plan driver supply or incentives.',
                ),
                const SizedBox(height: ReportUI.gapM),

                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Peak Created Hour',
                        value: '$peakCreatedHour:00',
                        subtitle: '$peakCreatedVal rides',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Peak Completed Hour',
                        value: '$peakCompletedHour:00',
                        subtitle: '$peakCompletedVal rides',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ReportUI.gapXL),

                _buildHourlyChart(
                  title: 'Created Rides per Hour (Demand)',
                  subtitle: 'Shows when users request rides the most.',
                  data: created,
                  color: createdColor,
                  isCreatedChart: true,
                ),

                _buildHourlyChart(
                  title: 'Completed Rides per Hour (Fulfilled)',
                  subtitle: 'Shows when rides are successfully completed.',
                  data: completed,
                  color: completedColor,
                  isCreatedChart: false,
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
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}