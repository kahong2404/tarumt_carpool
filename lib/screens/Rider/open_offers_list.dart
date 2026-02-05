import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/driver_offer_repository.dart';
import 'package:tarumt_carpool/utils/geo_utils.dart';

enum NearbyMode { pickup, dropoff }

class RideOfferFilter {
  final double radiusKm;               // nearby radius
  final GeoPoint? centerGeo;           // user selected location
  final String? centerAddress;         // for UI
  final NearbyMode nearbyMode;         // pickup OR dropoff
  final int minSeats;                  // seatsAvailable >= minSeats
  final bool sortByFareAsc;            // sort by fare low->high

  const RideOfferFilter({
    this.radiusKm = 10,
    this.centerGeo,
    this.centerAddress,
    this.nearbyMode = NearbyMode.pickup,
    this.minSeats = 1,
    this.sortByFareAsc = true,
  });

  bool get hasCenter => centerGeo != null;

  RideOfferFilter copyWith({
    double? radiusKm,
    GeoPoint? centerGeo,
    String? centerAddress,
    NearbyMode? nearbyMode,
    int? minSeats,
    bool? sortByFareAsc,
  }) {
    return RideOfferFilter(
      radiusKm: radiusKm ?? this.radiusKm,
      centerGeo: centerGeo ?? this.centerGeo,
      centerAddress: centerAddress ?? this.centerAddress,
      nearbyMode: nearbyMode ?? this.nearbyMode,
      minSeats: minSeats ?? this.minSeats,
      sortByFareAsc: sortByFareAsc ?? this.sortByFareAsc,
    );
  }
}

class OpenOffersList extends StatelessWidget {
  final RideOfferFilter filter;
  const OpenOffersList({super.key, required this.filter});

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
        final filtered = _applyFilterAndSort(offers);

        if (filtered.isEmpty) return const _EmptyRideState();

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _DriverOfferCard(
            offer: filtered[i],
            filter: filter,
          ),
        );
      },
    );
  }

  List<DriverOffer> _applyFilterAndSort(List<DriverOffer> offers) {
    final out = <DriverOffer>[];

    for (final o in offers) {
      // seats
      if (o.seatsAvailable < filter.minSeats) continue;

      // nearby center
      if (filter.hasCenter) {
        final c = filter.centerGeo!;
        final GeoPoint target =
        (filter.nearbyMode == NearbyMode.pickup) ? o.pickupGeo : o.destinationGeo;

        final km = distanceKm(
          lat1: c.latitude,
          lon1: c.longitude,
          lat2: target.latitude,
          lon2: target.longitude,
        );

        if (km > filter.radiusKm) continue;
      }

      out.add(o);
    }

    // sort by fare
    if (filter.sortByFareAsc) {
      out.sort((a, b) => a.fare.compareTo(b.fare));
    } else {
      out.sort((a, b) => b.fare.compareTo(a.fare));
    }

    return out;
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
  final RideOfferFilter filter;

  const _DriverOfferCard({required this.offer, required this.filter});

  @override
  Widget build(BuildContext context) {
    final dt = offer.rideDateTime;

    final dateText =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeText =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    String? nearbyText;
    if (filter.hasCenter) {
      final c = filter.centerGeo!;
      final GeoPoint target =
      (filter.nearbyMode == NearbyMode.pickup) ? offer.pickupGeo : offer.destinationGeo;

      final km = distanceKm(
        lat1: c.latitude,
        lon1: c.longitude,
        lat2: target.latitude,
        lon2: target.longitude,
      );

      nearbyText =
      '${km.toStringAsFixed(1)} km from selected ${filter.nearbyMode == NearbyMode.pickup ? "pickup" : "dropoff"}';
    }

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
            '$dateText • $timeText • ${offer.seatsAvailable} seat(s)',
            style: const TextStyle(color: Colors.black54, height: 1.3),
          ),
          if (nearbyText != null) ...[
            const SizedBox(height: 4),
            Text(nearbyText, style: const TextStyle(color: Colors.black54)),
          ],
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
