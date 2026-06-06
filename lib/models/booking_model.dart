import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  String id;
  String houseId;
  String houseTitle;
  String houseImageUrl;
  String houseLocation;
  String tenantId;
  String tenantName;
  String tenantEmail;
  String landlordId;
  DateTime moveInDate;
  int rentalDurationMonths; // duration in months
  DateTime createdAt;
  DateTime updatedAt;
  String status; // 'pending', 'confirmed', 'rejected', 'completed', 'cancelled'
  String? message; // optional message from landlord or tenant
  String
      verificationStatus; // 'verified', 'pending', 'rejected', 'not_verified'

  BookingModel({
    required this.id,
    required this.houseId,
    required this.houseTitle,
    required this.houseImageUrl,
    required this.houseLocation,
    required this.tenantId,
    required this.tenantName,
    required this.tenantEmail,
    required this.landlordId,
    required this.moveInDate,
    required this.rentalDurationMonths,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.message,
    required this.verificationStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'houseTitle': houseTitle,
      'houseImageUrl': houseImageUrl,
      'houseLocation': houseLocation,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'tenantEmail': tenantEmail,
      'landlordId': landlordId,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'rentalDurationMonths': rentalDurationMonths,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      'message': message,
      'verificationStatus': verificationStatus,
    };
  }

  factory BookingModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      houseId: data['houseId'] ?? '',
      houseTitle: data['houseTitle'] ?? '',
      houseImageUrl: data['houseImageUrl'] ?? '',
      houseLocation: data['houseLocation'] ?? '',
      tenantId: data['tenantId'] ?? '',
      tenantName: data['tenantName'] ?? '',
      tenantEmail: data['tenantEmail'] ?? '',
      landlordId: data['landlordId'] ?? '',
      moveInDate:
          (data['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rentalDurationMonths: (data['rentalDurationMonths'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      message: data['message'],
      verificationStatus: data['verificationStatus'] ?? 'not_verified',
    );
  }

  BookingModel copyWith({
    String? id,
    String? houseId,
    String? houseTitle,
    String? houseImageUrl,
    String? houseLocation,
    String? tenantId,
    String? tenantName,
    String? tenantEmail,
    String? landlordId,
    DateTime? moveInDate,
    int? rentalDurationMonths,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? message,
    String? verificationStatus,
  }) {
    return BookingModel(
      id: id ?? this.id,
      houseId: houseId ?? this.houseId,
      houseTitle: houseTitle ?? this.houseTitle,
      houseImageUrl: houseImageUrl ?? this.houseImageUrl,
      houseLocation: houseLocation ?? this.houseLocation,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      tenantEmail: tenantEmail ?? this.tenantEmail,
      landlordId: landlordId ?? this.landlordId,
      moveInDate: moveInDate ?? this.moveInDate,
      rentalDurationMonths: rentalDurationMonths ?? this.rentalDurationMonths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      message: message ?? this.message,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}
