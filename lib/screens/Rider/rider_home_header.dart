import 'package:flutter/material.dart';

class RiderHomeHeader extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onCreateRequestTap;
  final VoidCallback onWalletTap;
  final VoidCallback onFilterTap;
  final VoidCallback onScheduleTap;
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ shrink to content
        children: [
          _SearchBar(
            hintText: 'Pick Up At?',
            onTap: onCreateRequestTap,
          ),
          const SizedBox(height: 12),

          // ✅ Row-based grid — no fixed aspect ratio, tiles grow with content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _QuickTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        onTap: onWalletTap,
                      ),
                      const SizedBox(height: 10),
                      _QuickTile(
                        icon: Icons.calendar_month_outlined,
                        title: 'Schedule\nBooking',
                        onTap: onScheduleTap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _QuickTile(
                        icon: Icons.tune,
                        title: 'Filter',
                        onTap: onFilterTap,
                      ),
                      const SizedBox(height: 10),
                      _QuickTile(
                        icon: Icons.event_note_outlined,
                        title: 'My\nScheduled',
                        onTap: onMyScheduledTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ shrink to content, no overflow
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.2, // ✅ slightly more line height to avoid clipping
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}