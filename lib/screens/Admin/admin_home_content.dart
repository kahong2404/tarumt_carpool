import 'package:flutter/material.dart';

class AdminHomeContent extends StatelessWidget {
  const AdminHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E73FF);

    return Column(
      children: [
        // ✅ Same style as rider header (blue top)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Verification List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),

              // Optional quick tiles (same like rider quick tiles)
              Row(
                children: [
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.pending_actions_outlined,
                      title: 'Pending',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.verified_outlined,
                      title: 'Approved',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.block_outlined,
                      title: 'Rejected',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ✅ Body list (same pattern as _OpenOffersList)
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _DriverVerificationList(),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// Driver Verification List (UI-only)
/// ===============================
class _DriverVerificationList extends StatelessWidget {
  const _DriverVerificationList();

  @override
  Widget build(BuildContext context) {
    // UI-only fake data (replace with StreamBuilder later)
    final items = const [
      _DriverVerifyVM(
        name: 'Chong Ka Hong',
        userId: '2314524',
        dateText: '15 April 2025',
        status: _VerifyStatus.pending,
      ),
      _DriverVerifyVM(
        name: 'Ho Yi Von',
        userId: '2314542',
        dateText: '11 December 2025',
        status: _VerifyStatus.approved,
      ),
      _DriverVerifyVM(
        name: 'Chong Chee Wee',
        userId: '2314523',
        dateText: '25 May 2025',
        status: _VerifyStatus.rejected,
      ),
    ];

    if (items.isEmpty) return const _EmptyState(text: 'No driver verification records');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _DriverVerifyCard(
        vm: items[i],
        onReviewTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Open driver verification detail (later).')),
          );
        },
      ),
    );
  }
}

enum _VerifyStatus { pending, approved, rejected }

class _DriverVerifyVM {
  final String name;
  final String userId;
  final String dateText;
  final _VerifyStatus status;

  const _DriverVerifyVM({
    required this.name,
    required this.userId,
    required this.dateText,
    required this.status,
  });
}

class _DriverVerifyCard extends StatelessWidget {
  final _DriverVerifyVM vm;
  final VoidCallback onReviewTap;

  const _DriverVerifyCard({required this.vm, required this.onReviewTap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (vm.status) {
      _VerifyStatus.pending => ('Pending', Colors.amber),
      _VerifyStatus.approved => ('Approved', Colors.green),
      _VerifyStatus.rejected => ('Rejected', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(text: label, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(vm.userId, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(vm.dateText, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onReviewTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E73FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Click for Review',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// ===============================
/// Tab 1: Suspicious Review Content
/// ===============================
class SuspiciousReviewContent extends StatelessWidget {
  const SuspiciousReviewContent({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E73FF);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suspicious Review List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.star_border,
                      title: 'Low Rating',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.report_outlined,
                      title: 'Reported',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.filter_alt_outlined,
                      title: 'Filter',
                      height: 64,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _SuspiciousReviewList(),
          ),
        ),
      ],
    );
  }
}

class _SuspiciousReviewList extends StatelessWidget {
  const _SuspiciousReviewList();

  @override
  Widget build(BuildContext context) {
    // UI-only fake data
    final items = const [
      _ReviewVM(name: 'Alice', comment: 'The driver is worst. XXX', dateText: '15 April 2025', stars: 1),
      _ReviewVM(name: 'Aldeline', comment: 'The driver is sohx..', dateText: '11 December 2025', stars: 1),
      _ReviewVM(name: 'Lee Yi Liang', comment: 'I hate the driver!!!', dateText: '25 May 2025', stars: 1),
    ];

    if (items.isEmpty) return const _EmptyState(text: 'No suspicious reviews');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _SuspiciousReviewCard(
        vm: items[i],
        onReviewTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Open review moderation detail (later).')),
          );
        },
      ),
    );
  }
}

class _ReviewVM {
  final String name;
  final String comment;
  final String dateText;
  final int stars;

  const _ReviewVM({
    required this.name,
    required this.comment,
    required this.dateText,
    required this.stars,
  });
}

class _SuspiciousReviewCard extends StatelessWidget {
  final _ReviewVM vm;
  final VoidCallback onReviewTap;

  const _SuspiciousReviewCard({required this.vm, required this.onReviewTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StarRow(stars: vm.stars),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vm.comment,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87, height: 1.25),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(vm.dateText, style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: onReviewTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E73FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Click for Review',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        stars,
            (_) => const Icon(Icons.star, size: 18, color: Colors.amber),
      ),
    );
  }
}

/// ===============================
/// Shared QuickTile (same as rider)
/// ===============================
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool centerTitle;
  final VoidCallback onTap;
  final double height;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.height,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black54)),
        ],
      ),
    );
  }
}
