import 'package:flutter/material.dart';
import 'package:tarumt_carpool/screens/Admin/Report/completion_report_screen.dart';

// ✅ Import each report screen here
import 'Report/peak_hour_report_screen.dart';
import 'Report/revenue_report_screen.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Add new report cards by adding a new item here
    // Team member guide:
    // 1) Create new report screen (e.g., cancellation_report_screen.dart)
    // 2) Import it above
    // 3) Add a ReportItem below with title/subtitle/icon/screenBuilder
    final reports = <ReportItem>[
      ReportItem(
        title: 'Peak Hour Report',
        subtitle: 'Created vs Completed per hour (0–23)',
        icon: Icons.bar_chart_rounded,
        screenBuilder: (_) => const PeakHourCreatedCompletedReportScreen(),
      ),

      ReportItem(
        title: 'Completion Report',
        subtitle: 'Completion & cancellation rate',
        icon: Icons.check_circle_outline,
        screenBuilder: (_) => const CompletionReportScreen(),
      ),

      ReportItem(
        title: 'Revenue Report',
        subtitle: 'Total revenue & average fare',
        icon: Icons.payments_outlined,
        screenBuilder: (_) => const RevenueReportScreen(),
      ),

      // ============================================================
      // ✅ TEAMMATE: ADD NEW REPORTS BELOW
      // Example:
      //
      // ReportItem(
      //   title: 'Cancellation Report',
      //   subtitle: 'Cancellation by hour + reason',
      //   icon: Icons.cancel_outlined,
      //   screenBuilder: (_) => const CancellationReportScreen(),
      // ),
      //
      // ReportItem(
      //   title: 'Revenue Report',
      //   subtitle: 'Total revenue & average fare',
      //   icon: Icons.payments_outlined,
      //   screenBuilder: (_) => const RevenueReportScreen(),
      // ),
      // ============================================================
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reports',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Analytics for admin decision making',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  itemCount: reports.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 cards per row
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    return _ReportCard(
                      title: r.title,
                      subtitle: r.subtitle,
                      icon: r.icon,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: r.screenBuilder),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder screenBuilder;

  ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screenBuilder,
  });
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}