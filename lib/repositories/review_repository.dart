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
}


