//only the header + offers UI
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/rider_request_repository.dart';
import 'package:tarumt_carpool/repositories/rides_offer_repository.dart';
import 'package:tarumt_carpool/widgets/LocationSearch/location_select_screen.dart';
import 'package:tarumt_carpool/widgets/seat_request_dialog.dart';

class RiderHomeContent extends StatelessWidget {
  const RiderHomeContent({super.key});

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
            children: [
              _SearchBar(
                hintText: 'Pick Up At?',
                onSearchTap: () async {
                  final pickup = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationSelectScreen(
                        mode: LocationSelectMode.pickup,
                        initialTarget: LatLng(3.2149, 101.7291),
                      ),
                    ),
                  );
                  if (pickup == null) return;

                  final pickupLatLng = LatLng(pickup["lat"], pickup["lng"]);

                  final dropoff = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationSelectScreen(
                        mode: LocationSelectMode.dropoff,
                        initialTarget: pickupLatLng,
                      ),
                    ),
                  );
                  if (dropoff == null) return;

                  final originAddress = (pickup["address"] ?? "").toString().trim();
                  final destinationAddress = (dropoff["address"] ?? "").toString().trim();

                  // 🔹 Ask seat count
                  final seatRequested = await showDialog<int>(
                    context: context,
                    builder: (_) => const SeatRequestDialog(),
                  );

                  if (seatRequested == null) return;

// 🔹 Use current system time
                  final now = DateTime.now();
                  final rideDate =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final rideTime =
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

// 🔹 Save to Firestore
                  final repo = RiderRequestRepository();

                  try {
                    final requestId = await repo.createRiderRequest(
                      origin: originAddress,
                      destination: destinationAddress,
                      rideDate: rideDate,
                      rideTime: rideTime,
                      seatRequested: seatRequested,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Request created ($seatRequested seat)')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'RM100',
                      height: 72,
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _OpenOffersList(),
          ),
        ),
      ],
    );
  }
}

// ✅ FIX: InkWell must have Material above it
class _SearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback onSearchTap;

  const _SearchBar({required this.hintText, required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onSearchTap,
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
          const Text('No ride offers available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          ),
        ],
      ),
    );
  }
}

class _OpenOffersList extends StatelessWidget {
  _OpenOffersList({super.key});
  final _repo = DriverOfferRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverOffer>>(
      stream: _repo.streamOpenOffers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load ride offers.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
          );
        }

        final offers = snapshot.data ?? [];
        if (offers.isEmpty) return const _EmptyRideState();

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _DriverOfferCard(offer: offers[i]),
        );
      },
    );
  }
}

class _DriverOfferCard extends StatelessWidget {
  final DriverOffer offer;
  const _DriverOfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final dt = offer.rideDateTime;

    final dateText = dt == null
        ? 'Date not set'
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    final timeText = dt == null
        ? ''
        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: "From: ", style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                TextSpan(text: offer.pickup, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: "To: ", style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                TextSpan(text: offer.destination, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$dateText ${timeText.isEmpty ? "" : "• $timeText"} • ${offer.seatsAvailable} seat(s)',
            style: const TextStyle(color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('RM ${offer.fare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('View')),
            ],
          ),
        ],
      ),
    );
  }
}
