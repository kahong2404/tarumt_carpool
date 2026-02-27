import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewRepository {
  final FirebaseFirestore _db;
  ReviewRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get rides => _db.collection('rides'); //rides → points to Firestore collection "rides"
  CollectionReference<Map<String, dynamic>> get reviews => _db.collection('rating_Reviews'); //reviews → points to Firestore collection "rating_Reviews"

  //So if the review changes in Firestore:
  // UI automatically updates.
  //show the review for the specific reviewId
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamReviewById(String reviewId) {
    return reviews.doc(reviewId).snapshots(); //snapshots means realtime updates
  }

  //show all the review for the driver Id
  Stream<QuerySnapshot<Map<String, dynamic>>> streamDriverVisibleReviews(String driverId) {
    return reviews
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'visible')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

//filter and sort review in driver side
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

//change the review status to not suspicious
  Future<void> adminMarkNotSuspicious(String reviewId) async {
    await reviews.doc(reviewId).update({
      'isSuspicious': false,
      'visibility': 'visible',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  //admin delete the review (soft delete)
  Future<void> adminDeleteReview(String reviewId) async {
    // soft delete (recommended)
    await reviews.doc(reviewId).update({
      'status': 'deleted',
      'visibility': 'hidden',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}


