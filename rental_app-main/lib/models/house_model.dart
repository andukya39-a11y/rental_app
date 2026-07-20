import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

String? _pickImageUrl(Map<String, dynamic> data) {
  if (data['imageUrl'] is String && (data['imageUrl'] as String).isNotEmpty) {
    return data['imageUrl'] as String;
  }
  if (data['primary_image'] is String &&
      (data['primary_image'] as String).isNotEmpty) {
    return data['primary_image'] as String;
  }
  final imgs = data['images'];
  if (imgs is List && imgs.isNotEmpty && imgs.first is Map) {
    final url = (imgs.first as Map)['media_url'];
    if (url is String && url.isNotEmpty) return url;
  }
  return null;
}

class HouseModel {
  String id;
  String userId;
  String title;
  String description;
  double price;
  String location;
  int bedrooms;
  int bathrooms;
  bool isAvailable;
  String? imageUrl;
  bool isVerified;
  double? latitude;
  double? longitude;
  DateTime createdAt;
  DateTime updatedAt;
  String? propertyType;
  String verificationStatus;
  String? shehaName;
  String? shehia;
  DateTime? verificationDate;
  String? landlordName;
  String? landlordEmail;
  int minRentalMonths;

  HouseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.bedrooms,
    required this.bathrooms,
    required this.isAvailable,
    this.imageUrl,
    this.isVerified = false,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.propertyType,
    this.verificationStatus = 'not_verified',
    this.shehaName,
    this.shehia,
    this.verificationDate,
    this.landlordName,
    this.landlordEmail,
    this.minRentalMonths = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'isAvailable': isAvailable,
      'imageUrl': imageUrl,
      'isVerified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
      'propertyType': propertyType,
      'verificationStatus': verificationStatus,
      'shehaName': shehaName,
      'shehia': shehia,
      'landlordName': landlordName,
      'landlordEmail': landlordEmail,
      'minRentalMonths': minRentalMonths,
    };
  }

  factory HouseModel.fromJson(Map<String, dynamic> data, {String id = ''}) {
    return HouseModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      userId: data['userId'] ?? data['owner_id']?.toString() ?? '',
      title: data['title'] ?? data['property_name'] ?? '',
      description: data['description'] ?? '',
      price: double.tryParse(data['price']?.toString() ?? '') ?? 0.0,
      location: data['location'] ?? '',
      bedrooms: int.tryParse(
              (data['bedrooms'] ?? data['number_of_rooms'])?.toString() ?? '') ??
          0,
      bathrooms: int.tryParse(data['bathrooms']?.toString() ?? '') ?? 0,
      isAvailable: data['isAvailable'] ??
          (data['availability_status'] == 'available'),
      imageUrl: _pickImageUrl(data),
      isVerified: data['isVerified'] == true || data['is_verified'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      propertyType: data['propertyType'] ?? data['category']?['category_name'],
      verificationStatus: data['verificationStatus'] ??
          (data['isVerified'] == true ? 'verified' : 'not_verified'),
      shehaName: data['shehaName'],
      shehia: data['shehia'],
      verificationDate: data['verificationDate'] != null
          ? _parseDate(data['verificationDate'])
          : null,
      landlordName: data['landlordName'] ?? data['owner']?['name'],
      landlordEmail: data['landlordEmail'] ?? data['owner']?['email'],
      minRentalMonths: int.tryParse(
              (data['minRentalMonths'] ?? 1).toString()) ??
          1,
    );
  }

  HouseModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    double? price,
    String? location,
    int? bedrooms,
    int? bathrooms,
    bool? isAvailable,
    String? imageUrl,
    bool? isVerified,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? propertyType,
    String? verificationStatus,
    String? shehaName,
    String? shehia,
    DateTime? verificationDate,
    String? landlordName,
    String? landlordEmail,
    int? minRentalMonths,
  }) {
    return HouseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      location: location ?? this.location,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      propertyType: propertyType ?? this.propertyType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      shehaName: shehaName ?? this.shehaName,
      shehia: shehia ?? this.shehia,
      verificationDate: verificationDate ?? this.verificationDate,
      landlordName: landlordName ?? this.landlordName,
      landlordEmail: landlordEmail ?? this.landlordEmail,
      minRentalMonths: minRentalMonths ?? this.minRentalMonths,
    );
  }
}
