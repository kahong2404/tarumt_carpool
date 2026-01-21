import 'package:flutter/material.dart';

import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/driver_offer_repository.dart';

class OpenOffersList extends StatelessWidget {
  const OpenOffersList({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DriverOfferRepository();

    return StreamBuilder<List<DriverOffer>>(
      stream: repo.streamOpenOffers(),
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
          ),
        ],
      ),
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
                const TextSpan(
                  text: "From: ",
                  style: TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                TextSpan(
                  text: offer.pickup,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: "To: ",
                  style: TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                TextSpan(
                  text: offer.destination,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
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
              Text('RM ${offer.fare.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('View')),
            ],
          ),
        ],
      ),
    );
  }
}
