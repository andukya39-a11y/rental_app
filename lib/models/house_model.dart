import 'package:cloud_firestore/cloud_firestore.dart';

class HouseModel {
  String id;
  String userId; // ID of the user who added the house
  String title;
  String description;
  double price;
  String location;
  int bedrooms;
  int bathrooms;
  bool isAvailable;
  String? imageUrl; // URL of the uploaded image
  bool
      isVerified; // Verification status by admin (Shehia) - Kept for backward compatibility
  double? latitude; // Latitude coordinate
  double? longitude; // Longitude coordinate
  DateTime createdAt;
  DateTime updatedAt;
  String? propertyType; // Type of property: 'Room', 'Apartment', 'House', etc.

  // New verification fields for Sheha verification
  String
      verificationStatus; // 'not_verified', 'pending', 'verified', 'rejected'
  String? shehaName; // Name of the Sheha who verified
  String? shehia; // Name of the Shehia (area) where verified
  DateTime? verificationDate; // Date when verification was done

  // Landlord information (for display in Sheha dashboard)
  String? landlordName;
  String? landlordEmail;

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
    // New fields with default values
    this.verificationStatus = 'not_verified',
    this.shehaName,
    this.shehia,
    this.verificationDate,
    this.landlordName,
    this.landlordEmail,
  });

  // Convert HouseModel to Map for Firestore
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'propertyType': propertyType,
      // New verification fields
      'verificationStatus': verificationStatus,
      'shehaName': shehaName,
      'shehia': shehia,
      'verificationDate': verificationDate != null
          ? Timestamp.fromDate(verificationDate!)
          : null,
      // Landlord info
      'landlordName': landlordName,
      'landlordEmail': landlordEmail,
    };
  }

  // Create HouseModel from Firestore Document
  factory HouseModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      location: data['location'] ?? '',
      bedrooms: (data['bedrooms'] ?? 0).toInt(),
      bathrooms: (data['bathrooms'] ?? 0).toInt(),
      isAvailable: data['isAvailable'] ?? true,
      imageUrl: data['imageUrl'],
      isVerified: data['isVerified'] ?? false,
      latitude: data['latitude'] != null
          ? (data['latitude'] as num).toDouble()
          : null,
      longitude: data['longitude'] != null
          ? (data['longitude'] as num).toDouble()
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      propertyType: data['propertyType'],
      // New verification fields
      verificationStatus: data['verificationStatus'] ?? 'not_verified',
      shehaName: data['shehaName'],
      shehia: data['shehia'],
      verificationDate: (data['verificationDate'] as Timestamp?)?.toDate(),
      // Landlord info
      landlordName: data['landlordName'],
      landlordEmail: data['landlordEmail'],
    );
  }

  // CopyWith method for easy updates
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
    // New verification fields
    String? verificationStatus,
    String? shehaName,
    String? shehia,
    DateTime? verificationDate,
    // Landlord info
    String? landlordName,
    String? landlordEmail,
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
      // New verification fields
      verificationStatus: verificationStatus ?? this.verificationStatus,
      shehaName: shehaName ?? this.shehaName,
      shehia: shehia ?? this.shehia,
      verificationDate: verificationDate ?? this.verificationDate,
      // Landlord info
      landlordName: landlordName ?? this.landlordName,
      landlordEmail: landlordEmail ?? this.landlordEmail,
    );
  }
}
