import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewRepository {
  final FirebaseFirestore _db;
  ReviewRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get rides => _db.collection('rides');
  CollectionReference<Map<String, dynamic>> get reviews => _db.collection('rating_Reviews');

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamReviewById(String reviewId) {
    return reviews.doc(reviewId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverVisibleReviews(String driverId) {
    return reviews
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'visible')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverAllReviewsAdmin(String driverId) {
    return reviews
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverVisibleReviewsFiltered({
    required String driverId,
    required bool descending,
    int? star, // null = all
  }) {
    Query<Map<String, dynamic>> q = reviews
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'visible');

    if (star != null) {
      q = q.where('ratingScore', isEqualTo: star);
    }

    q = q.orderBy('createdAt', descending: descending);

    return q.snapshots();
  }

  // -------- ADMIN side --------
  // filter: null=all, true=suspicious, false=not suspicious
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAdminReviewsFiltered({
    required bool descending,
    bool? suspiciousFilter,
    int? star, // ⭐ NEW
  }) {
    Query<Map<String, dynamic>> q =
    reviews.where('status', isEqualTo: 'active');

    if (suspiciousFilter != null) {
      q = q.where('isSuspicious', isEqualTo: suspiciousFilter);
    }

    if (star != null) {
      q = q.where('ratingScore', isEqualTo: star);
    }

    q = q.orderBy('createdAt', descending: descending);

    return q.snapshots();
  }


  Future<void> adminMarkNotSuspicious(String reviewId) async {
    await reviews.doc(reviewId).update({
      'isSuspicious': false,
      'visibility': 'visible',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminDeleteReview(String reviewId) async {
    // soft delete (recommended)
    await reviews.doc(reviewId).update({
      'status': 'deleted',
      'visibility': 'hidden',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}


