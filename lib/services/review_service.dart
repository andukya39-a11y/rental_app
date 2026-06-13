import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_app/models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'reviews';

  Future<void> addReview({
    required String houseId,
    required String houseTitle,
    required double rating,
    String? comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final review = ReviewModel(
      id: '',
      houseId: houseId,
      houseTitle: houseTitle,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
      userPhotoUrl: user.photoURL,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collectionName).add(review.toMap());
  }

  Stream<List<ReviewModel>> getReviewsByHouse(String houseId) {
    return _firestore
        .collection(_collectionName)
        .where('houseId', isEqualTo: houseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReviewModel.fromDocument(doc)).toList());
  }

  Future<double> getAverageRating(String houseId) async {
    final snapshot =
        await _firestore.collection(_collectionName).where('houseId', isEqualTo: houseId).get();

    if (snapshot.docs.isEmpty) return 0.0;

    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['rating'] ?? 0.0).toDouble();
    }
    return total / snapshot.docs.length;
  }

  Future<int> getReviewCount(String houseId) async {
    final snapshot =
        await _firestore.collection(_collectionName).where('houseId', isEqualTo: houseId).get();
    return snapshot.docs.length;
  }

  Future<List<ReviewModel>> getReviewsByUser(String userId) async {
    final snapshot =
        await _firestore.collection(_collectionName).where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((doc) => ReviewModel.fromDocument(doc)).toList();
  }

  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection(_collectionName).doc(reviewId).delete();
  }

  Future<bool> hasUserReviewed(String houseId, String userId) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('houseId', isEqualTo: houseId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}