import 'package:flutter/material.dart';

class RiderHomePage extends StatelessWidget {
  const RiderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E73FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // white
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Header with safe sizes (no overflow)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                children: [
                  _SearchBar(
                    hintText: 'Pick Up At?',
                    onSearchTap: () {},
                  ),
                  const SizedBox(height: 12),

                  // ✅ Use fixed smaller height + text constraints
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'RM100',
                          height: 72, // 👈 smaller to avoid overflow
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.tune,
                          title: 'Filter',
                          height: 72,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.calendar_month_outlined,
                          title: 'Schedule\nBooking',
                          height: 72,
                          centerTitle: true,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Your list area (you said list is OK)
            // For now, show empty state as in your screenshot
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: _EmptyRideState(),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
        onTap: (_) {},
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback onSearchTap;

  const _SearchBar({
    required this.hintText,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onSearchTap,
      child: Container(
        height: 42, // ✅ slightly smaller
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
    );
  }
}

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
            crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),

              // ✅ Prevent text from pushing height
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

class _EmptyRideState extends StatelessWidget {
  const _EmptyRideState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          const Text(
            'No ride offers available',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'There are currently no drivers offering rides.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.refresh, color: color),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
