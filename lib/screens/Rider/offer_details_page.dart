import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tarumt_carpool/repositories/rider_request_repository.dart';
import 'package:tarumt_carpool/services/google_direction_service.dart';
import 'package:tarumt_carpool/services/route_metrics_service.dart';
import 'package:tarumt_carpool/screens/Rider/rider_waiting_map_screen.dart'; // optional navigation

class OfferDetailsPage extends StatefulWidget {
  final String offerId;

  const OfferDetailsPage({
    super.key,
    required this.offerId,
  });

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  final _db = FirebaseFirestore.instance;
  final RiderRequestRepository _repo = RiderRequestRepository();

  bool _submitting = false;
  int _requestedSeats = 1;

  static const String offersCol = 'driver_offers';

  // ✅ reuse your directions service
  late final GoogleDirectionsService _directions;
  late final RouteMetricsService _metrics;

  DocumentReference<Map<String, dynamic>> get _offerRef =>
      _db.collection(offersCol).doc(widget.offerId);

  @override
  void initState() {
    super.initState();
    _directions = GoogleDirectionsService('AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA');
    _metrics = RouteMetricsService(_directions);
  }

  String _formatDT(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d • $t';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _acceptOffer({
    required Map<String, dynamic> offerData,
  }) async {
    final status = (offerData['status'] ?? '') as String;
    final int seatsAvailable = (offerData['seatsAvailable'] ?? 0) as int;

    if (status != 'open') {
      _snack('This offer is not open anymore.');
      return;
    }
    if (_requestedSeats < 1) {
      _snack('Please select at least 1 seat.');
      return;
    }
    if (seatsAvailable < _requestedSeats) {
      _snack('Not enough seats available.');
      return;
    }

    final pickupGeo = offerData['pickupGeo'];
    final destinationGeo = offerData['destinationGeo'];
    if (pickupGeo is! GeoPoint || destinationGeo is! GeoPoint) {
      _snack('Offer location coordinates missing.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm acceptance'),
        content: Text('Accept this ride for $_requestedSeats seat(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _submitting = true);

    try {
      // ✅ 1) compute REAL route metrics once using Google Directions
      final metrics = await _metrics.computeFromGeoPoints(
        pickupGeo: pickupGeo,
        destinationGeo: destinationGeo,
      );

      // ✅ 2) create riderRequests + decrement seats
      final requestId = await _repo.acceptOfferAndCreateRequest(
        offerId: widget.offerId,
        seatRequested: _requestedSeats,
        routeDistanceKm: metrics.distanceKm,
        routeDurationText: metrics.durationText,
      );

      if (!mounted) return;
      _snack('Offer accepted! Request created.');

      // ✅ optional: go to waiting screen immediately
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RiderWaitingMapScreen(requestId: requestId),
        ),
      );
    } on ActiveRideExistsException catch (e) {
      _snack(e.message);
    } on WalletMinimumException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Offer')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _offerRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Offer not found.'));
          }

          final data = snapshot.data!.data()!;
          final pickup = (data['pickup'] ?? '') as String;
          final destination = (data['destination'] ?? '') as String;
          final status = (data['status'] ?? '') as String;
          final int seatsAvailable = (data['seatsAvailable'] ?? 0) as int;
          final fare = (data['fare'] ?? 0) as num;

          final ts = data['rideDateTime'];
          final DateTime rideDT =
          (ts is Timestamp) ? ts.toDate() : DateTime.now();

          final canAccept =
              status == 'open' && seatsAvailable > 0 && !_submitting;

          final maxSeats = seatsAvailable.clamp(1, 99);
          if (_requestedSeats > maxSeats) _requestedSeats = maxSeats;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
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
                    Text('From',
                        style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    Text(pickup,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text('To',
                        style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    Text(destination,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(_formatDT(rideDT),
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event_seat,
                            size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('$seatsAvailable seat(s) available',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_offer,
                            size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('RM ${fare.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (status == 'open')
                                ? cs.primary.withOpacity(0.12)
                                : Colors.black12.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: (status == 'open')
                                  ? cs.primary
                                  : Colors.black54,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Text('Seats to book',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: (!canAccept || _requestedSeats <= 1)
                          ? null
                          : () => setState(() => _requestedSeats--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_requestedSeats',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: (!canAccept || _requestedSeats >= maxSeats)
                          ? null
                          : () => setState(() => _requestedSeats++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canAccept ? () => _acceptOffer(offerData: data) : null,
                icon: _submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Accepting...' : 'Accept Offer'),
              ),
              if (status != 'open') ...[
                const SizedBox(height: 8),
                const Text(
                  'This offer is not available anymore.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}