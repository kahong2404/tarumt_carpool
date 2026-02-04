import 'package:cloud_firestore/cloud_firestore.dart';

class RatingReview {
  final String id;

  final String rideId;
  final String driverId;
  final String riderId;

  final String reviewerType; // "rider"
  final int ratingScore;
  final String commentText;

  final Timestamp? createdAt;

  // moderation
  final bool isSuspicious;
  final String status; // "active" / "deleted"
  final String visibility; // "visible" / "hidden"

  const RatingReview({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.riderId,
    required this.reviewerType,
    required this.ratingScore,
    required this.commentText,
    required this.createdAt,
    required this.isSuspicious,
    required this.status,
    required this.visibility,
  });

  factory RatingReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw Exception('RatingReview has no data: ${doc.id}');

    final rawScore = data['ratingScore'];

    return RatingReview(
      id: doc.id,
      rideId: (data['rideId'] ?? '').toString(),
      driverId: (data['driverId'] ?? '').toString(),
      riderId: (data['riderId'] ?? '').toString(),
      reviewerType: (data['reviewerType'] ?? '').toString(),
      ratingScore: rawScore is int ? rawScore : (rawScore as num?)?.toInt() ?? 0,
      commentText: (data['commentText'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
      isSuspicious: (data['isSuspicious'] ?? false) == true,
      status: (data['status'] ?? 'active').toString(),
      visibility: (data['visibility'] ?? 'visible').toString(),
    );
  }
}
