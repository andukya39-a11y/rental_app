import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Sheha verification request document
/// stored in the 'verification_requests' Firestore collection.
class VerificationRequestModel {
  final String id;
  final String houseId;
  final String landlordId;
  final String shehia;
  final DateTime? requestDate;

  VerificationRequestModel({
    required this.id,
    required this.houseId,
    required this.landlordId,
    required this.shehia,
    this.requestDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'landlordId': landlordId,
      'shehia': shehia,
      if (requestDate != null) 'requestDate': Timestamp.fromDate(requestDate!),
    };
  }

  factory VerificationRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VerificationRequestModel(
      id: doc.id,
      houseId: data['houseId'] ?? '',
      landlordId: data['landlordId'] ?? '',
      shehia: data['shehia'] ?? '',
      requestDate: (data['requestDate'] as Timestamp?)?.toDate(),
    );
  }
}
