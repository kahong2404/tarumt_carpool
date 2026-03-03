import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tarumt_carpool/repositories/rider_request_repository.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

class RiderScheduledBookingsScreen extends StatelessWidget {
  final RiderRequestRepository repo;
  const RiderScheduledBookingsScreen({super.key, required this.repo});

  String _moneyRm(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Scheduled Bookings',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.streamMyScheduledRequests(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No scheduled bookings yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final requestId = (data['requestId'] ?? docs[i].id).toString();

              final pickup = (data['pickupAddress'] ?? '-').toString();
              final dest = (data['destinationAddress'] ?? '-').toString();
              final seat = (data['seatRequested'] ?? 1).toString();
              final fareCents = (data['finalFare'] ?? 0) as int;

              final ts = data['scheduledAt'];
              final dt = ts is Timestamp ? ts.toDate() : null;
              final when = dt == null ? '-' : DateFormat('dd MMM yyyy, h:mm a').format(dt);

              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        when,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('From: $pickup'),
                      Text('To: $dest'),
                      const SizedBox(height: 6),
                      Text('Seat: $seat   •   Fare: ${_moneyRm(fareCents)}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  await repo.cancelRequest(requestId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Scheduled booking cancelled.')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}