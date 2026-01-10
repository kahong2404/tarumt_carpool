import 'package:flutter/material.dart';
import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/rides_offer_repository.dart';
import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/models/app_user.dart';
import 'package:tarumt_carpool/screens/edit_post_screen.dart';
import 'package:tarumt_carpool/screens/create_post_rides_screen.dart';


class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final _userRepo = UserRepository();
  Future<AppUser?>? _meFuture;

  @override
  void initState() {
    super.initState();
    _meFuture = _userRepo.getCurrentUser();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _meFuture = _userRepo.getCurrentUser(); // refresh welcome name too
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _DriverBottomNav(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================
                // Header: Welcome
                // =========================
                FutureBuilder<AppUser?>(
                  future: _meFuture,
                  builder: (context, snap) {
                    String displayName = "Driver";
                    if (snap.hasData && snap.data != null) {
                      final user = snap.data!;
                      final name = (user.email ?? '').trim();
                      if (name.isNotEmpty) displayName = name;
                    }
                    return Text(
                      "Welcome, $displayName",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // =========================
                // Quick Actions
                // =========================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickAction(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "RM100",
                      onTap: () {},
                    ),
                    _QuickAction(
                      icon: Icons.add_box_outlined,
                      title: "Post Rider Offer",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PostRides()),
                        );
                        await _onRefresh(); // refresh after coming back
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // =========================
                // My Ride Post
                // =========================
                Text(
                  "My Ride Post",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                _MyRidePostsPreview(
                  onCreateTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostRides()),
                    );
                    await _onRefresh();
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _MyRidePostsPreview extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _MyRidePostsPreview({required this.onCreateTap});

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  Future<bool> _confirm(BuildContext context, String title, String msg, String okText) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Back")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(okText)),
        ],
      ),
    );
    return res == true;
  }

  Widget _statusBadge(DriverOfferStatus status) {
    final label = statusToString(status); // from your model
    // simple color choice
    final Color bg = switch (status) {
      DriverOfferStatus.open => const Color(0xFFE7F3FF),
      DriverOfferStatus.cancelled => const Color(0xFFFFE9E9),
      DriverOfferStatus.booked => const Color(0xFFFFF4D6),
      DriverOfferStatus.completed => const Color(0xFFE8F7EE),
    };
    final Color fg = switch (status) {
      DriverOfferStatus.open => const Color(0xFF2B6CFF),
      DriverOfferStatus.cancelled => Colors.red,
      DriverOfferStatus.booked => const Color(0xFFB7791F),
      DriverOfferStatus.completed => const Color(0xFF1F7A3F),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = DriverOfferRepository();

    return StreamBuilder<List<DriverOffer>>(
      stream: repo.streamMine(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snap.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: Text("Error loading posts: ${snap.error}"),
          );
        }

        final offers = snap.data ?? [];

        if (offers.isEmpty) {
          return _EmptyRidePostState(onCreateTap: onCreateTap);
        }

        final preview = offers.length > 3 ? offers.take(3).toList() : offers;

        return Column(
          children: [
            ...preview.map((o) {
              final offerId = o.offerId; // should exist from Firestore doc id

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: offerId == null
                    ? null
                    : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPostScreenRides(offerId: offerId),
                    ),
                  );
                  // No manual refresh needed: stream updates automatically
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.route_outlined,
                          color: Color(0xFF2B6CFF),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // title + status badge
// pickup + destination + status badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Pickup
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: "From: ",
                                              style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            TextSpan(
                                              text: o.pickup,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 3),

                                      // Destination
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: "To: ",
                                              style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            TextSpan(
                                              text: o.destination,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Status badge stays the same
                                _statusBadge(o.status),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Text(
                              "Time: ${_fmtDateTime(o.rideDateTime)}",
                              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                            ),
                            Text(
                              "Seats: ${o.seatsAvailable}  •  RM ${o.fare.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                            ),

                            const SizedBox(height: 10),

                            // action buttons
                            Row(
                              children: [

                                const SizedBox(width: 8),

                                const Spacer(),

                                IconButton(
                                  tooltip: "Delete",
                                  onPressed: (offerId == null)
                                      ? null
                                      : () async {
                                    final ok = await _confirm(
                                      context,
                                      "Delete offer?",
                                      "This will permanently delete the post.",
                                      "Delete",
                                    );
                                    if (!ok) return;
                                    await repo.delete(offerId);
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (offers.length > 3)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    // Optional: navigate to full page list
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostedRidesPage()));
                  },
                  child: const Text("View all my posts"),
                ),
              ),
          ],
        );
      },
    );
  }
}


/// Quick Action button (icon + label like your screenshot)
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF), // light blue background
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 26,
                color: const Color(0xFF2B6CFF), // primary blue
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for My Ride Post (shows when no posts)
class _EmptyRidePostState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyRidePostState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 30,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No ride posts yet",
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Create a ride offer so riders can request your carpool.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                "Post Rider Offer",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B6CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom navigation like screenshot (home, list, bell, profile)
class _DriverBottomNav extends StatelessWidget {
  final int currentIndex;

  const _DriverBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black45,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      onTap: (index) {
        // TODO: handle navigation later
        // Example:
        // if(index==0) Navigator.push(...DriverHomePage)
        // if(index==1) Navigator.push(...RideHistoryPage)
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          label: "Posts",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none_outlined),
          label: "Notifications",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: "Profile",
        ),
      ],
    );
  }
}
