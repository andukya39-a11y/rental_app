import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

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
  int rentalDurationMonths;
  DateTime createdAt;
  DateTime updatedAt;
  String status;
  String? message;
  String verificationStatus;

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
      'moveInDate': moveInDate.toIso8601String(),
      'rentalDurationMonths': rentalDurationMonths,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'message': message,
      'verificationStatus': verificationStatus,
    };
  }

  factory BookingModel.fromJson(Map<String, dynamic> data, {String id = ''}) {
    return BookingModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      houseId: data['houseId'] ?? data['property_id']?.toString() ?? '',
      houseTitle: data['houseTitle'] ?? '',
      houseImageUrl: data['houseImageUrl'] ?? '',
      houseLocation: data['houseLocation'] ?? '',
      tenantId: data['tenantId'] ?? data['tenant_id']?.toString() ?? '',
      tenantName: data['tenantName'] ?? '',
      tenantEmail: data['tenantEmail'] ?? '',
      landlordId: data['landlordId'] ?? '',
      moveInDate: _parseDate(data['moveInDate'] ?? data['booking_start_date']),
      rentalDurationMonths: int.tryParse(
              (data['rentalDurationMonths'] ?? data['duration_months'] ?? 1)
                  .toString()) ??
          1,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      status: data['status'] ?? data['booking_status'] ?? 'pending',
      message: data['message'] ?? data['notes'],
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
