import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/review_repository.dart';
import '../../utils/reviews/review_moderation.dart';

class ReviewService {
  final ReviewRepository _repo;
  final FirebaseAuth _auth;

  ReviewService({
    ReviewRepository? repo,
    FirebaseAuth? auth,
  })  : _repo = repo ?? ReviewRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Submit rider review:
  /// - rider only
  /// - only after ride completed
  /// - only once
  /// - writes: rating_Reviews + rides patch (transaction)
  Future<({String reviewId, bool suspicious})> submitRiderReview({
    required String rideId,
    required int ratingScore,
    required String commentText,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    if (ratingScore < 1 || ratingScore > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    final comment = commentText.trim();

    final suspicious = ReviewModeration.detectSuspicious(
      comment: comment,
    );

    final visibility = suspicious ? 'hidden' : 'visible';


    final rideRef = _repo.rides.doc(rideId);

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw Exception('Ride not found');

      final ride = rideSnap.data() ?? <String, dynamic>{};
      final riderId = (ride['riderID'] ?? '').toString().trim();
      final driverId = (ride['driverID'] ?? '').toString().trim();
      final status = (ride['rideStatus'] ?? '').toString().trim();
      final hasReview = (ride['hasReview'] ?? false) == true;

      if (riderId.isEmpty || driverId.isEmpty) {
        throw Exception('Ride missing riderID/driverID');
      }
      if (uid != riderId) {
        throw Exception('Only rider can submit this review');
      }
      if (status != 'completed') {
        throw Exception('Ride not completed yet');
      }
      if (hasReview) {
        throw Exception('Review already submitted');
      }

      final reviewRef = _repo.reviews.doc();
      final now = FieldValue.serverTimestamp();

      tx.set(reviewRef, {
        'rideId': rideId,
        'driverId': driverId,
        'riderId': riderId,
        'reviewerType': 'rider',
        'ratingScore': ratingScore,
        'commentText': comment,
        'createdAt': now,
        'updatedAt': now,
        'isSuspicious': suspicious,
        'visibility': visibility,
        'status': 'active',
      });

      tx.update(rideRef, {
        'hasReview': true,
        'reviewId': reviewRef.id,
        'reviewUpdatedAt': now,
        'updatedAt': now,
      });

      return (reviewId: reviewRef.id, suspicious: suspicious);
    });
  }

}
