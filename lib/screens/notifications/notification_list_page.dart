import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';

class NotificationListPage extends StatelessWidget {
  NotificationListPage({super.key});

  final _repo = NotificationRepository();
  static const bg = Color(0xFFF5F6FA);
  static const brandBlue = Color(0xFF1E73FF);

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final diff = DateTime.now().difference(d);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'driver_verification':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Notification'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.streamMyNotifications(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snap.error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final items = docs
              .map((d) => AppNotification.fromDoc(d.id, d.data()))
              .toList();

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = items[i];

              return InkWell(
                onTap: () async {
                  if (!n.isRead) await _repo.markRead(n.id);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForType(n.type),
                        color: n.isRead ? Colors.black38 : brandBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight:
                                      n.isRead ? FontWeight.w700 : FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _timeAgo(n.createdAt),
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.message,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
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
