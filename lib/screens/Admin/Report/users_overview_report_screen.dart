import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/report_ui.dart';

enum ReportRange { today, last7, last30 }

class UsersOverviewReportScreen extends StatefulWidget {
  const UsersOverviewReportScreen({super.key});

  @override
  State<UsersOverviewReportScreen> createState() =>
      _UsersOverviewReportScreenState();
}

class _UsersOverviewReportScreenState extends State<UsersOverviewReportScreen> {
  static const Color newColor = Color(0xFF1E73FF);
  static const Color activeColor = Color(0xFF2ECC71);

  static const int bucketDaysFor30 = 7;
  static const int bucketHoursForToday = 3;

  ReportRange _range = ReportRange.last7;

  // ✅ Cache the future so tapping bars doesn't re-query Firestore
  late Future<_UsersOverviewResult> _future;

  // ✅ Tooltip state (overlay like Pie)
  int _touchedGroupIndex = -1; // which x group
  int _touchedRodIndex = -1; // 0 = New, 1 = Active
  Offset? _tooltipPos;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    setState(() {
      _touchedGroupIndex = -1;
      _touchedRodIndex = -1;
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

  String _chartTitle(_UsersOverviewResult res) {
    if (res.isWeekly) return 'New vs Active Users (by week)';
    if (res.isThreeHourly) return 'New vs Active Users (by 3 hours)';
    return 'New vs Active Users (by day)';
  }

  String _yAxisTitle(ReportRange r) {
    switch (r) {
      case ReportRange.today:
        return 'Users (today, per 3 hrs)';
      case ReportRange.last7:
        return 'Users (last 7 days)';
      case ReportRange.last30:
        return 'Users (last 30 days)';
    }
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime _bucket3hKey(DateTime dt) {
    final h = (dt.hour ~/ bucketHoursForToday) * bucketHoursForToday;
    return DateTime(dt.year, dt.month, dt.day, h);
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

  String _formatMd(DateTime d) => '${d.month}/${d.day}';
  String _formatHm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';
  String _formatHmMin(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<_UsersOverviewResult> _load() async {
    final (start, end) = _getRangeWindow(_range);

    final totalSnap = await FirebaseFirestore.instance.collection('users').get();
    final totalUsers = totalSnap.size;

    final newSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final activeSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    // daily maps for last7/last30
    final Map<DateTime, int> newByDay = {};
    for (final doc in newSnap.docs) {
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final d = _dayKey(ts.toDate().toLocal());
      newByDay[d] = (newByDay[d] ?? 0) + 1;
    }

    final Map<DateTime, int> activeByDay = {};
    for (final doc in activeSnap.docs) {
      final ts = doc.data()['updatedAt'] as Timestamp?;
      if (ts == null) continue;
      final d = _dayKey(ts.toDate().toLocal());
      activeByDay[d] = (activeByDay[d] ?? 0) + 1;
    }

    // ✅ TODAY: 3-hour buckets
    if (_range == ReportRange.today) {
      final Map<DateTime, int> newBy3h = {};
      for (final doc in newSnap.docs) {
        final ts = doc.data()['createdAt'] as Timestamp?;
        if (ts == null) continue;
        final k = _bucket3hKey(ts.toDate().toLocal());
        newBy3h[k] = (newBy3h[k] ?? 0) + 1;
      }

      final Map<DateTime, int> activeBy3h = {};
      for (final doc in activeSnap.docs) {
        final ts = doc.data()['updatedAt'] as Timestamp?;
        if (ts == null) continue;
        final k = _bucket3hKey(ts.toDate().toLocal());
        activeBy3h[k] = (activeBy3h[k] ?? 0) + 1;
      }

      final startBucket = DateTime(end.year, end.month, end.day, 0);
      final lastBucket = DateTime(end.year, end.month, end.day, 21);

      final points = <DateTime>[];
      DateTime cursor = startBucket;
      while (!cursor.isAfter(lastBucket)) {
        points.add(cursor);
        cursor = cursor.add(const Duration(hours: bucketHoursForToday));
      }

      final newSeries = points.map((h) => newBy3h[h] ?? 0).toList();
      final activeSeries = points.map((h) => activeBy3h[h] ?? 0).toList();

      final endDates = points
          .map((h) => h.add(const Duration(hours: 2, minutes: 59, seconds: 59)))
          .toList();

      return _UsersOverviewResult(
        totalUsers: totalUsers,
        newUsers: newSnap.size,
        activeUsers: activeSnap.size,
        points: points,
        pointEndDates: endDates,
        newSeries: newSeries,
        activeSeries: activeSeries,
        isWeekly: false,
        isThreeHourly: true,
      );
    }

    // ✅ LAST30: weekly buckets
    if (_range == ReportRange.last30) {
      final List<DateTime> bucketStarts = [];
      final List<DateTime> bucketEnds = [];
      final List<int> newSeries = [];
      final List<int> activeSeries = [];

      DateTime cursor = _dayKey(start.toLocal());
      final lastDay = _dayKey(end.toLocal());

      while (!cursor.isAfter(lastDay)) {
        final rangeStart = cursor;
        var rangeEnd = cursor.add(const Duration(days: bucketDaysFor30 - 1));
        if (rangeEnd.isAfter(lastDay)) rangeEnd = lastDay;

        int newSum = 0;
        int activeSum = 0;

        DateTime inner = rangeStart;
        while (!inner.isAfter(rangeEnd)) {
          newSum += newByDay[inner] ?? 0;
          activeSum += activeByDay[inner] ?? 0;
          inner = inner.add(const Duration(days: 1));
        }

        bucketStarts.add(rangeStart);
        bucketEnds.add(rangeEnd);
        newSeries.add(newSum);
        activeSeries.add(activeSum);

        cursor = rangeEnd.add(const Duration(days: 1));
      }

      return _UsersOverviewResult(
        totalUsers: totalUsers,
        newUsers: newSnap.size,
        activeUsers: activeSnap.size,
        points: bucketStarts,
        pointEndDates: bucketEnds,
        newSeries: newSeries,
        activeSeries: activeSeries,
        isWeekly: true,
        isThreeHourly: false,
      );
    }

    // ✅ LAST7: daily buckets
    final points = <DateTime>[];
    DateTime cursor = _dayKey(start.toLocal());
    final lastDay = _dayKey(end.toLocal());
    while (!cursor.isAfter(lastDay)) {
      points.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    final newSeries = points.map((d) => newByDay[d] ?? 0).toList();
    final activeSeries = points.map((d) => activeByDay[d] ?? 0).toList();

    return _UsersOverviewResult(
      totalUsers: totalUsers,
      newUsers: newSnap.size,
      activeUsers: activeSnap.size,
      points: points,
      pointEndDates: points,
      newSeries: newSeries,
      activeSeries: activeSeries,
      isWeekly: false,
      isThreeHourly: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final yAxisTitle = _yAxisTitle(_range);
    final xAxisTitle = _bottomAxisTitle(_range);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Overview Report'),
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
                setState(() {
                  _range = v;
                });
                _reload(); // ✅ reload data ONLY when range changes
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<_UsersOverviewResult>(
        future: _future, // ✅ cached future
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final res = snap.data ?? _UsersOverviewResult.empty();

          final maxY = _maxInt([...res.newSeries, ...res.activeSeries]);
          final yMax = (maxY == 0 ? 1 : maxY + 1);
          final interval = _niceInterval(yMax).toDouble();

          return Padding(
            padding: ReportUI.pagePadding,
            child: ListView(
              children: [
                const ReportInfoBox(
                  title: 'What this report means',
                  body:
                  'This report shows total users, new registrations and active updates within the selected time range. '
                      'Use it to track user growth and engagement.',
                ),
                const SizedBox(height: ReportUI.gapM),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Total Users',
                            value: res.totalUsers.toString(),
                            subtitle: 'All time',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            title: 'New Users',
                            value: res.newUsers.toString(),
                            subtitle: _rangeLabel(_range),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            title: 'Active Users',
                            value: res.activeUsers.toString(),
                            subtitle: _rangeLabel(_range),
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

                // ✅ Chart + custom tooltip overlay
                ReportChartBox(
                  chart: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          BarChart(
                            BarChartData(
                              minY: 0,
                              maxY: yMax.toDouble(),
                              borderData:
                              FlBorderData(show: true, border: ReportUI.chartBorder),
                              gridData: ReportUI.grid(),
                              extraLinesData: ReportUI.baseline0(),
                              barGroups: List.generate(res.points.length, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barsSpace: 8,
                                  barRods: [
                                    BarChartRodData(
                                      toY: res.newSeries[i].toDouble(),
                                      width: 12,
                                      color: newColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    BarChartRodData(
                                      toY: res.activeSeries[i].toDouble(),
                                      width: 12,
                                      color: activeColor,
                                      borderRadius: BorderRadius.circular(4),
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

                              // ✅ Custom overlay tooltip (no rebuild reload)
                              barTouchData: BarTouchData(
                                enabled: true,
                                handleBuiltInTouches: false,
                                touchCallback: (event, rsp) {
                                  if (rsp == null || rsp.spot == null) {
                                    setState(() {
                                      _touchedGroupIndex = -1;
                                      _touchedRodIndex = -1;
                                      _tooltipPos = null;
                                    });
                                    return;
                                  }

                                  if (event is! FlTapUpEvent) return;

                                  final spot = rsp.spot!;
                                  setState(() {
                                    _touchedGroupIndex = spot.touchedBarGroupIndex;
                                    _touchedRodIndex = spot.touchedRodDataIndex;
                                    _tooltipPos = event.localPosition;
                                  });
                                },
                              ),
                            ),
                          ),

                          if (_touchedGroupIndex >= 0 &&
                              _touchedRodIndex >= 0 &&
                              _tooltipPos != null)
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

                // ✅ Legend card (like Roles legend)
                Center(
                  child: SizedBox(
                    width: 220,
                    child: ReportLegendCard(
                      title: 'Type of Users',
                      items: const [
                        ReportLegendItem(color: newColor, label: 'New users'),
                        ReportLegendItem(color: activeColor, label: 'Active users'),
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

  Widget _buildTooltip(_UsersOverviewResult res) {
    final idx = _touchedGroupIndex;
    final rod = _touchedRodIndex;

    final isNew = rod == 0;
    final color = isNew ? newColor : activeColor;
    final label = isNew ? 'New' : 'Active';
    final value = isNew ? res.newSeries[idx] : res.activeSeries[idx];

    final start = res.points[idx];
    final end = res.pointEndDates[idx];

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
      line2: '$label: $value',
      color: color,
    );
  }
}

class _UsersOverviewResult {
  final int totalUsers;
  final int newUsers;
  final int activeUsers;

  final List<DateTime> points;
  final List<DateTime> pointEndDates;

  final List<int> newSeries;
  final List<int> activeSeries;

  final bool isWeekly;
  final bool isThreeHourly;

  _UsersOverviewResult({
    required this.totalUsers,
    required this.newUsers,
    required this.activeUsers,
    required this.points,
    required this.pointEndDates,
    required this.newSeries,
    required this.activeSeries,
    required this.isWeekly,
    required this.isThreeHourly,
  });

  factory _UsersOverviewResult.empty() => _UsersOverviewResult(
    totalUsers: 0,
    newUsers: 0,
    activeUsers: 0,
    points: const [],
    pointEndDates: const [],
    newSeries: const [],
    activeSeries: const [],
    isWeekly: false,
    isThreeHourly: false,
  );
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
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