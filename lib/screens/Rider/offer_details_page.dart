import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferDetailsPage extends StatefulWidget {
  final String offerId;

  /// Provide riderId from your auth (FirebaseAuth.currentUser!.uid)
  /// If you prefer, pass it in from previous screen.
  const OfferDetailsPage({
    super.key,
    required this.offerId,
  });

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  final _db = FirebaseFirestore.instance;

  bool _submitting = false;
  int _requestedSeats = 1;

  // CHANGE THIS to your actual offers collection name
  static const String offersCol = 'driver_offers';

  // CHANGE THIS to your actual bookings collection name
  static const String bookingsCol = 'ride_bookings';

  DocumentReference<Map<String, dynamic>> get _offerRef =>
      _db.collection(offersCol).doc(widget.offerId);

  String _formatDT(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d • $t';
  }

  Future<void> _acceptOffer({
    required Map<String, dynamic> offerData,
  }) async {
    // TODO: replace with FirebaseAuth.currentUser!.uid
    const String riderId = 'REPLACE_WITH_AUTH_UID';

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

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm acceptance'),
        content: Text('Accept this ride for $_requestedSeats seat(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accept')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _submitting = true);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_offerRef);
        if (!snap.exists) {
          throw Exception('Offer not found.');
        }

        final data = snap.data()!;
        final currentStatus = (data['status'] ?? '') as String;
        final int currentSeats = (data['seatsAvailable'] ?? 0) as int;

        if (currentStatus != 'open') {
          throw Exception('Offer is no longer open.');
        }
        if (currentSeats < _requestedSeats) {
          throw Exception('Seats just got taken. Please try again.');
        }

        final newSeats = currentSeats - _requestedSeats;

        // Decide what status should become after acceptance:
        // If seats become 0 -> close it. Otherwise keep open.
        final newStatus = (newSeats == 0) ? 'closed' : 'open';

        tx.update(_offerRef, {
          'seatsAvailable': newSeats,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create a booking / acceptance record
        final bookingRef = _db.collection(bookingsCol).doc();

        tx.set(bookingRef, {
          'bookingId': bookingRef.id,
          'offerId': widget.offerId,
          'driverId': data['driverId'],
          'riderId': riderId,
          'seatsBooked': _requestedSeats,
          'fare': data['fare'],
          'pickup': data['pickup'],
          'destination': data['destination'],
          'rideDateTime': data['rideDateTime'],
          'status': 'accepted', // you can change to "pending" if you want driver approval
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      _snack('Offer accepted!');

      // Optional: go back to list page
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Offer'),
      ),
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
          final DateTime rideDT = (ts is Timestamp) ? ts.toDate() : DateTime.now();

          final canAccept = status == 'open' && seatsAvailable > 0 && !_submitting;

          // Keep requested seats in valid range automatically
          final maxSeats = seatsAvailable.clamp(1, 99);
          if (_requestedSeats > maxSeats) {
            _requestedSeats = maxSeats;
          }

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
                    Text('From', style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    Text(pickup, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    Text('To', style: TextStyle(color: Colors.black.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    Text(destination, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(_formatDT(rideDT), style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.event_seat, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('$seatsAvailable seat(s) available',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.local_offer, size: 18, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('RM ${fare.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              color: (status == 'open') ? cs.primary : Colors.black54,
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
                    const Text('Seats to book', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: (!canAccept || _requestedSeats <= 1)
                          ? null
                          : () => setState(() => _requestedSeats--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_requestedSeats', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                onPressed: canAccept
                    ? () => _acceptOffer(offerData: data)
                    : null,
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