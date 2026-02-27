import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportUI {
  // Global paddings
  static const EdgeInsets pagePadding = EdgeInsets.all(16);

  // Standard vertical spacing
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXL = 18;

  // Cards
  static const double cardRadius = 12;
  static const EdgeInsets cardPadding = EdgeInsets.all(12);

  // Chart sizing + top padding so top ticks never look clipped
  static const double chartHeight = 320;
  static const double chartTopPadding = 12;

  // Axis styling
  static const double axisNameSize = 22;
  static const double leftReservedSize = 42;
  static const double leftTitleSpaceFromAxis = 6;

  // Axis lines
  static const Border chartBorder = Border(
    left: BorderSide(color: Colors.black87, width: 1.5),
    bottom: BorderSide(color: Colors.black87, width: 1.5),
    top: BorderSide(color: Colors.transparent),
    right: BorderSide(color: Colors.transparent),
  );

  static FlGridData grid() => FlGridData(
    show: true,
    drawVerticalLine: true,
    getDrawingHorizontalLine: (value) => FlLine(
      color: Colors.black12,
      strokeWidth: 1,
    ),
    getDrawingVerticalLine: (value) => FlLine(
      color: Colors.black12,
      strokeWidth: 1,
    ),
  );

  static ExtraLinesData baseline0() => ExtraLinesData(
    horizontalLines: [
      HorizontalLine(
        y: 0,
        color: Colors.black,
        strokeWidth: 2,
      ),
    ],
  );

  static AxisTitles leftAxis({
    required String title,
    required double interval,
    String Function(double v)? format,
  }) {
    return AxisTitles(
      axisNameWidget: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      axisNameSize: axisNameSize,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: leftReservedSize,
        interval: interval,
        getTitlesWidget: (value, meta) {
          final text = format?.call(value) ?? value.toInt().toString();
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: leftTitleSpaceFromAxis,
            child: Text(text, style: const TextStyle(fontSize: 12)),
          );
        },
      ),
    );
  }

  static AxisTitles bottomAxis({
    required String title,
    required double interval,
    required Widget Function(double value, TitleMeta meta) getTitle,
  }) {
    return AxisTitles(
      axisNameWidget: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      axisNameSize: 30,
      sideTitles: SideTitles(
        showTitles: true,
        interval: interval,
        getTitlesWidget: getTitle,
      ),
    );
  }

  // ============================================================
  // ✅ STANDARD TOOLTIP STYLE (fl_chart ^0.68.0)
  // ============================================================

  static const Color tooltipBg = Color(0xFF4A4A4A);
  static const double tooltipRadius = 12;
  static const EdgeInsets tooltipPadding =
  EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  static const TextStyle tooltipText = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// ✅ Built-in BarChart tooltip style (background / padding / radius)
  /// Note: built-in tooltip text only (cannot insert widgets like color square)
  static BarTouchTooltipData barTooltip({
    required BarTooltipItem? Function(
        BarChartGroupData group,
        int groupIndex,
        BarChartRodData rod,
        int rodIndex,
        ) getItem,
  }) {
    return BarTouchTooltipData(
      getTooltipColor: (_) => tooltipBg, // ✅ correct for 0.68.x
      tooltipRoundedRadius: tooltipRadius,
      tooltipPadding: tooltipPadding,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItem: getItem,
    );
  }
}

/// Standard info card (same look for all reports)
class ReportInfoBox extends StatelessWidget {
  final String title;
  final String body;

  const ReportInfoBox({
    super.key,
    required this.title,
    required this.body,
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard chart container so height/padding always same
class ReportChartBox extends StatelessWidget {
  final Widget chart;

  const ReportChartBox({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ReportUI.chartHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: ReportUI.chartTopPadding),
        child: chart,
      ),
    );
  }
}

/// ✅ Reusable legend card (same style as Roles legend)
class ReportLegendCard extends StatelessWidget {
  final String title;
  final List<ReportLegendItem> items;

  const ReportLegendCard({
    super.key,
    required this.title,
    required this.items,
  });

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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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

class ReportLegendItem {
  final Color color;
  final String label;
  const ReportLegendItem({required this.color, required this.label});
}

/// ✅ Floating tooltip widget (same design as your pie tooltip)
class ReportFloatingTooltip extends StatelessWidget {
  final String title;
  final String line2;
  final String? line3;
  final Color color;

  const ReportFloatingTooltip({
    super.key,
    required this.title,
    required this.line2,
    this.line3,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ReportUI.tooltipBg,
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
                line3 == null ? '$title\n$line2' : '$title\n$line2\n$line3',
                style: ReportUI.tooltipText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}