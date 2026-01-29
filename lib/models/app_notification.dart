import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final Timestamp? createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.data,
  });

  factory AppNotification.fromDoc(String id, Map<String, dynamic> d) {
    return AppNotification(
      id: id,
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      createdAt: d['createdAt'] as Timestamp?,
      isRead: (d['isRead'] ?? false) == true,
      data: Map<String, dynamic>.from(d['data'] ?? {}),
    );
  }
}
