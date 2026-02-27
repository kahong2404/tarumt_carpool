import 'package:flutter/material.dart';

import 'Report/users_overview_report_screen.dart';
import 'package:tarumt_carpool/screens/Admin/Report/completion_report_screen.dart';
import 'package:tarumt_carpool/screens/Admin/Report/users_role_distribution_report_screen.dart';
import 'Report/peak_hour_report_screen.dart';
import 'Report/revenue_report_screen.dart';
import 'package:tarumt_carpool/screens/Admin/Report/rating_distribution_report_screen.dart';
import 'package:tarumt_carpool/screens/Admin/Report/driver_verification_funnel_report_screen.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = <ReportItem>[
      ReportItem(
        title: 'Users Overview Report',
        icon: Icons.groups_rounded,
        screenBuilder: (_) => const UsersOverviewReportScreen(),
      ),
      ReportItem(
        title: 'Users Roles Distribution Report',
        icon: Icons.manage_accounts_outlined,
        screenBuilder: (_) => const UsersRoleDistributionReportScreen(),
      ),
      ReportItem(
        title: 'Driver Verification Funnel Report',
        icon: Icons.verified_user_outlined,
        screenBuilder: (_) => const DriverVerificationFunnelReportScreen(),
      ),
      ReportItem(
        title: 'Peak Hour Report',
        icon: Icons.bar_chart_rounded,
        screenBuilder: (_) => const PeakHourCreatedCompletedReportScreen(),
      ),
      ReportItem(
        title: 'Completion Report',
        icon: Icons.check_circle_outline,
        screenBuilder: (_) => const CompletionReportScreen(),
      ),
      ReportItem(
        title: 'Ratings Distribution Report',
        icon: Icons.star_rate_rounded,
        screenBuilder: (_) => const RatingDistributionReportScreen(),
      ),
      ReportItem(
        title: 'Revenue Report',
        icon: Icons.payments_outlined,
        screenBuilder: (_) => const RevenueReportScreen(),
      ),
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
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 160,
                  ),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    return _ReportCard(
                      title: r.title,
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
  final IconData icon;
  final WidgetBuilder screenBuilder;

  ReportItem({
    required this.title,
    required this.icon,
    required this.screenBuilder,
  });
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Centered Icon Box
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ✅ Centered Title
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}