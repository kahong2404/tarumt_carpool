import 'package:flutter/material.dart';

class RiderHomeHeader extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onCreateRequestTap;
  final VoidCallback onWalletTap;
  final VoidCallback onFilterTap;
  final VoidCallback onScheduleTap;

  // ✅ add this if you want "My Scheduled"
  final VoidCallback onMyScheduledTap;

  const RiderHomeHeader({
    super.key,
    required this.primaryColor,
    required this.onCreateRequestTap,
    required this.onWalletTap,
    required this.onFilterTap,
    required this.onScheduleTap,
    required this.onMyScheduledTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18), // ✅ slightly more bottom padding
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          _SearchBar(
            hintText: 'Pick Up At?',
            onTap: onCreateRequestTap,
          ),
          const SizedBox(height: 12),

          // ✅ 2x2 grid (fix overflow)
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2, // ✅ controls tile height (bigger = shorter)
            children: [
              _QuickTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet',
                centerTitle: true,
                onTap: onWalletTap,
              ),
              _QuickTile(
                icon: Icons.tune,
                title: 'Filter',
                centerTitle: true,
                onTap: onFilterTap,
              ),
              _QuickTile(
                icon: Icons.calendar_month_outlined,
                title: 'Schedule\nBooking',
                centerTitle: true,
                onTap: onScheduleTap,
              ),
              _QuickTile(
                icon: Icons.event_note_outlined,
                title: 'My\nScheduled',
                centerTitle: true,
                onTap: onMyScheduledTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;

  const _SearchBar({
    required this.hintText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hintText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool centerTitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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