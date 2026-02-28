import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tarumt_carpool/models/app_notification.dart';
import 'package:tarumt_carpool/repositories/notification_repository.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

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
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'driver_verification':
        return Icons.verified_user_outlined;
      case 'ride_request_status':
        return Icons.assignment_outlined;
      case 'ride_status':
        return Icons.directions_car_outlined;
      case 'new_request':
        return Icons.add_road_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

          final items =
          docs.map((d) => AppNotification.fromDoc(d.id, d.data())).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = items[i];
              final unread = !n.isRead;

              final cardBg = unread ? const Color(0xFFEFF5FF) : Colors.white;
              final borderColor =
              unread ? brandBlue.withOpacity(0.25) : Colors.black12;
              final iconColor = unread ? brandBlue : Colors.black45;
              final titleWeight = unread ? FontWeight.w900 : FontWeight.w800;

              return InkWell(
                onTap: () async {
                  if (unread) {
                    await _repo.markRead(n.id);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconForType(n.type), color: iconColor),
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
                                    style: TextStyle(fontWeight: titleWeight),
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