import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String houseId;
  final String houseTitle;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.houseId,
    required this.houseTitle,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'houseTitle': houseTitle,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      houseId: data['houseId'] ?? '',
      houseTitle: data['houseTitle'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}