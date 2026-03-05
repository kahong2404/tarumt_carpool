import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';
enum ReportRange { today, last7, last30 }

class RevenueReportScreen extends StatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

class _RevenueReportScreenState extends State<RevenueReportScreen> {
  static const Color revenueColor = Color(0xFF1E73FF);

  static const int bucketHoursForToday = 3;
  static const int bucketDaysFor30 = 7;

  ReportRange _range = ReportRange.last7;

  // ✅ cache future so tap doesn't re-query
  late Future<_RevenueRangeResult> _future;

  // ✅ tooltip overlay state
  int _touchedIndex = -1;
  Offset? _tooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    setState(() {
      _touchedIndex = -1;
      _tooltipPos = null;
      _future = _load();
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

  String _bottomAxisTitle(ReportRange r) {
    switch (r) {
      case ReportRange.today:
        return 'Time (3-hour blocks)';
      case ReportRange.last7:
        return 'Date';
      case ReportRange.last30:
        return 'Week';
    }
  }

  String _yAxisTitle(ReportRange r) {
    switch (r) {
      case ReportRange.today:
        return 'Revenue (RM) per 3 hrs';
      case ReportRange.last7:
        return 'Revenue (RM) per day';
      case ReportRange.last30:
        return 'Revenue (RM) per week';
    }
  }

  String _chartTitle(_RevenueRangeResult res) {
    if (res.isWeekly) return 'Revenue (by week)';
    if (res.isThreeHourly) return 'Revenue (by 3 hours)';
    return 'Revenue (by day)';
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime _bucket3hKey(DateTime dt) {
    final h = (dt.hour ~/ bucketHoursForToday) * bucketHoursForToday;
    return DateTime(dt.year, dt.month, dt.day, h);
  }

  String _formatMd(DateTime d) => '${d.month}/${d.day}';
  String _formatHm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';
  String _formatHmMin(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  double _maxDouble(List<double> a) =>
      a.isEmpty ? 0 : a.reduce((x, y) => x > y ? x : y);

  int _niceInterval(double maxY) {
    if (maxY <= 5) return 1;
    final raw = (maxY / 5).ceil();
    if (raw <= 2) return 2;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 20) return 20;
    if (raw <= 50) return 50;
    if (raw <= 100) return 100;
    return 200;
  }

  Future<_RevenueRangeResult> _load() async {
    final (start, end) = _getRangeWindow(_range);

    final snap = await FirebaseFirestore.instance
        .collection('rides')
        .where('rideStatus', isEqualTo: 'completed')
        .where('paymentStatus', isEqualTo: 'released')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double total = 0;
    int count = 0;

    // keep every ride record (datetime + amount) so we can bucket later
    final rides = <({DateTime dt, double amount})>[];

    for (final doc in snap.docs) {
      final data = doc.data();

      final fareNum = data['finalFare'];
      final fare = (fareNum is num) ? fareNum.toDouble() : 0.0;

      final ts = data['completedAt'] as Timestamp?;
      if (ts == null) continue;

      final dt = ts.toDate().toLocal();
      total += fare;
      count++;

      rides.add((dt: dt, amount: fare));
    }

    // ✅ TODAY: 3-hour buckets
    if (_range == ReportRange.today) {
      final Map<DateTime, double> by3h = {};
      for (final r in rides) {
        final k = _bucket3hKey(r.dt);
        by3h[k] = (by3h[k] ?? 0) + r.amount;
      }

      final points = <DateTime>[];
      final endDates = <DateTime>[];

      // 0,3,6,9,...,21
      final startBucket = DateTime(end.year, end.month, end.day, 0);
      final lastBucket = DateTime(end.year, end.month, end.day, 21);

      DateTime cursor = startBucket;
      while (!cursor.isAfter(lastBucket)) {
        points.add(cursor);
        endDates.add(cursor.add(const Duration(hours: 2, minutes: 59, seconds: 59)));
        cursor = cursor.add(const Duration(hours: bucketHoursForToday));
      }

      final values = points.map((p) => by3h[p] ?? 0.0).toList();

      return _RevenueRangeResult(
        total: total,
        count: count,
        avg: count == 0 ? 0 : total / count,
        points: points,
        pointEndDates: endDates,
        values: values,
        isWeekly: false,
        isThreeHourly: true,
      );
    }

    // ✅ LAST7: daily buckets
    if (_range == ReportRange.last7) {
      final Map<DateTime, double> byDay = {};
      for (final r in rides) {
        final k = _dayKey(r.dt);
        byDay[k] = (byDay[k] ?? 0) + r.amount;
      }

      final points = <DateTime>[];
      DateTime cursor = _dayKey(start.toLocal());
      final lastDay = _dayKey(end.toLocal());
      while (!cursor.isAfter(lastDay)) {
        points.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }

      final values = points.map((d) => byDay[d] ?? 0.0).toList();

      return _RevenueRangeResult(
        total: total,
        count: count,
        avg: count == 0 ? 0 : total / count,
        points: points,
        pointEndDates: points,
        values: values,
        isWeekly: false,
        isThreeHourly: false,
      );
    }

    // ✅ LAST30: weekly buckets (7-day blocks)
    final Map<DateTime, double> byDay = {};
    for (final r in rides) {
      final k = _dayKey(r.dt);
      byDay[k] = (byDay[k] ?? 0) + r.amount;
    }

    final bucketStarts = <DateTime>[];
    final bucketEnds = <DateTime>[];
    final values = <double>[];

    DateTime cursor = _dayKey(start.toLocal());
    final lastDay = _dayKey(end.toLocal());

    while (!cursor.isAfter(lastDay)) {
      final rangeStart = cursor;
      var rangeEnd = cursor.add(const Duration(days: bucketDaysFor30 - 1));
      if (rangeEnd.isAfter(lastDay)) rangeEnd = lastDay;

      double sum = 0.0;
      DateTime inner = rangeStart;
      while (!inner.isAfter(rangeEnd)) {
        sum += byDay[inner] ?? 0.0;
        inner = inner.add(const Duration(days: 1));
      }

      bucketStarts.add(rangeStart);
      bucketEnds.add(rangeEnd);
      values.add(sum);

      cursor = rangeEnd.add(const Duration(days: 1));
    }

    return _RevenueRangeResult(
      total: total,
      count: count,
      avg: count == 0 ? 0 : total / count,
      points: bucketStarts,
      pointEndDates: bucketEnds,
      values: values,
      isWeekly: true,
      isThreeHourly: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final yAxisTitle = _yAxisTitle(_range);
    final xAxisTitle = _bottomAxisTitle(_range);

    return AppScaffold(
      title: 'Revenue Report',
      actions: [
        DropdownButtonHideUnderline(
          child: DropdownButton<ReportRange>(
            value: _range,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.white), // on blue appbar
            iconEnabledColor: Colors.white,
            items: ReportRange.values.map((r) {
              return DropdownMenuItem(
                value: r,
                child: Text(
                  _rangeLabel(r),
                  style: const TextStyle(color: Colors.black), // menu text
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _range = v);
              _reload();
            },
          ),
        ),
        const SizedBox(width: 12),
      ],
      child: FutureBuilder<_RevenueRangeResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final res = snap.data ?? _RevenueRangeResult.empty();

          final maxVal = _maxDouble(res.values);
          final yMax = (maxVal == 0 ? 1.0 : maxVal * 1.2);
          final interval = _niceInterval(yMax).toDouble();

          return Padding(
            padding: ReportUI.pagePadding,
            child: ListView(
              children: [
                ReportInfoBox(
                  title: 'What this report means',
                  body:
                  'This report shows revenue from completed rides with payment status “released” for ${_rangeLabel(_range).toLowerCase()}. '
                      'Use it to track income trends and identify strong time periods.',
                ),
                const SizedBox(height: ReportUI.gapM),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Total Revenue',
                            value: 'RM ${res.total.toStringAsFixed(2)}',
                            subtitle: _rangeLabel(_range),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            title: 'Average Fare',
                            value: 'RM ${res.avg.toStringAsFixed(2)}',
                            subtitle: 'Per completed ride',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Paid Completed Rides',
                            value: res.count.toString(),
                            subtitle: 'paymentStatus: released',
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: ReportUI.gapXL),
                Text(
                  _chartTitle(res),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

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
                              barGroups: List.generate(res.values.length, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: res.values[i],
                                      width: 14,
                                      color: revenueColor,
                                      borderRadius: BorderRadius.circular(5),
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
                                  title: yAxisTitle,
                                  interval: interval,
                                  format: (v) => v.toStringAsFixed(0),
                                ),
                                bottomTitles: ReportUI.bottomAxis(
                                  title: xAxisTitle,
                                  interval: 1,
                                  getTitle: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= res.points.length) {
                                      return const SizedBox.shrink();
                                    }

                                    if (res.isWeekly) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text('Week ${i + 1}',
                                            style: const TextStyle(fontSize: 10)),
                                      );
                                    }

                                    final d = res.points[i];
                                    if (res.isThreeHourly) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text('${d.hour}',
                                            style: const TextStyle(fontSize: 10)),
                                      );
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_formatMd(d),
                                          style: const TextStyle(fontSize: 10)),
                                    );
                                  },
                                ),
                              ),
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
                              child: _buildTooltip(res),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: ReportLegendCard(
                      title: 'Revenue',
                      items: const [
                        ReportLegendItem(color: revenueColor, label: 'Revenue'),
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

  Widget _buildTooltip(_RevenueRangeResult res) {
    final idx = _touchedIndex;
    final start = res.points[idx];
    final end = res.pointEndDates[idx];
    final value = res.values[idx];

    String title;
    if (res.isWeekly) {
      title = 'Week ${idx + 1} (${_formatMd(start)} - ${_formatMd(end)})';
    } else if (res.isThreeHourly) {
      final endPretty = DateTime(end.year, end.month, end.day, end.hour, 59);
      title = '${_formatHm(start)} - ${_formatHmMin(endPretty)}';
    } else {
      title = '${start.year}-${start.month}-${start.day}';
    }

    return ReportFloatingTooltip(
      title: title,
      line2: 'RM ${value.toStringAsFixed(2)}',
      color: revenueColor,
    );
  }
}

class _RevenueRangeResult {
  final double total;
  final int count;
  final double avg;

  final List<DateTime> points;
  final List<DateTime> pointEndDates;
  final List<double> values;

  final bool isWeekly;
  final bool isThreeHourly;

  _RevenueRangeResult({
    required this.total,
    required this.count,
    required this.avg,
    required this.points,
    required this.pointEndDates,
    required this.values,
    required this.isWeekly,
    required this.isThreeHourly,
  });

  factory _RevenueRangeResult.empty() => _RevenueRangeResult(
    total: 0,
    count: 0,
    avg: 0,
    points: const [],
    pointEndDates: const [],
    values: const [],
    isWeekly: false,
    isThreeHourly: false,
  );
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
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}