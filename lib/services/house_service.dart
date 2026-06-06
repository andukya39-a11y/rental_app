import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/house_model.dart';
import '../utils/notification_service.dart';

class HouseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'houses';
  final NotificationService _notificationService = NotificationService();

  // Add a new house
  Future<void> addHouse(HouseModel house) async {
    try {
      // Set the userId to the current user's UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      final houseWithUserId = house.copyWith(
        userId: user.uid,
        landlordName: user.displayName,
        landlordEmail: user.email,
      );
      
      await _firestore.collection(_collectionName).add(houseWithUserId.toMap());
      // Send notification for new house
      _notificationService.showNotification('New house added: ${houseWithUserId.title} in ${houseWithUserId.location}');
    } catch (e) {
      throw Exception('Failed to add house: $e');
    }
  }

  // Get all houses with optional filtering
  Future<List<HouseModel>> getHouses({
    String? locationFilter,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? propertyTypeFilter,
  }) async {
    try {
      Query query = _firestore.collection(_collectionName);

      // Apply filters
      if (locationFilter != null && locationFilter.isNotEmpty) {
        query = query.where('location', isEqualTo: locationFilter);
      }
      
      if (minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: minPrice);
      }
      
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }
      
      if (propertyTypeFilter != null && propertyTypeFilter.isNotEmpty && propertyTypeFilter != 'All') {
        query = query.where('propertyType', isEqualTo: propertyTypeFilter);
      }
      
      // For rooms filtering, we'll filter bedrooms + bathrooms >= minRooms
      // Note: Firestore doesn't support complex queries easily, so we'll get all and filter in Dart
      // For a production app, you might want to denormalize or use a different approach
      
      final snapshot = await query.get();
      List<HouseModel> houses = snapshot.docs
          .map((doc) => HouseModel.fromDocument(doc))
          .toList();

      // Apply rooms filter in Dart (since Firestore doesn't support OR easily)
      if (minRooms != null) {
        houses = houses.where((house) {
          return (house.bedrooms + house.bathrooms) >= minRooms;
        }).toList();
      }

      return houses;
    } catch (e) {
      throw Exception('Failed to get houses: $e');
    }
  }

  // Get all houses as a stream with optional filtering
  Stream<List<HouseModel>> getHousesStream({
    String? locationFilter,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? propertyTypeFilter,
  }) {
    Query query = _firestore.collection(_collectionName);

    // Apply filters
    if (locationFilter != null && locationFilter.isNotEmpty) {
      query = query.where('location', isEqualTo: locationFilter);
    }
    
    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }
    
    if (propertyTypeFilter != null && propertyTypeFilter.isNotEmpty && propertyTypeFilter != 'All') {
      query = query.where('propertyType', isEqualTo: propertyTypeFilter);
    }

    return query.snapshots().map((snapshot) {
      List<HouseModel> houses = snapshot.docs
          .map((doc) => HouseModel.fromDocument(doc))
          .toList();

      // Apply rooms filter in Dart
      if (minRooms != null) {
        houses = houses.where((house) {
          return (house.bedrooms + house.bathrooms) >= minRooms;
        }).toList();
      }

      return houses;
    });
  }

  // Get a limited set of houses for recommendations (without filters)
  Stream<List<HouseModel>> getHousesForRecommendationsStream({int limit = 50}) {
    return _firestore
        .collection(_collectionName)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HouseModel.fromDocument(doc))
            .toList());
  }

  // Get multiple houses by their IDs
  Future<List<HouseModel>> getHousesByIds(List<String> houseIds) async {
    if (houseIds.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where(FieldPath.documentId, whereIn: houseIds)
          .get();
      return snapshot.docs
          .map((doc) => HouseModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get houses by IDs: $e');
    }
  }

  // Get houses by user ID
  Future<List<HouseModel>> getHousesByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs
          .map((doc) => HouseModel.fromDocument(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get houses for user: $e');
    }
  }

  // Get house by ID
  Future<HouseModel?> getHouseById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return HouseModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get house: $e');
    }
  }

  // Update house
  Future<void> updateHouse(HouseModel house) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(house.id)
          .update(house.toMap());
    } catch (e) {
      throw Exception('Failed to update house: $e');
    }
  }

  // Delete house
  Future<void> deleteHouse(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete house: $e');
    }
  }

  // Verify house (admin/Sheha function)
  Future<void> verifyHouse(String houseId, bool isVerized) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final houseDoc = _firestore.collection(_collectionName).doc(houseId);
      final houseSnapshot = await houseDoc.get();
      if (!houseSnapshot.exists) {
        throw Exception('House not found');
      }
      final house = HouseModel.fromDocument(houseSnapshot);

      await houseDoc.update({
        'isVerified': isVerized,
        'verificationStatus': isVerized ? 'verified' : 'rejected',
        'shehaName': user?.displayName,
        'shehia': house.location,
        'verificationDate': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to verify house: $e');
    }
  }

  // Request Sheha verification (landlord function)
  Future<void> requestShehaVerification(String houseId) async {
    try {
      // Get the house to get landlordId and shehia
      final houseDoc = await _firestore.collection(_collectionName).doc(houseId).get();
      if (!houseDoc.exists) {
        throw Exception('House not found');
      }
      final house = HouseModel.fromDocument(houseDoc);
      final landlordId = house.userId;
      final shehia = house.location;

      // Update the house verificationStatus to pending
      await _firestore.collection(_collectionName).doc(houseId).update({
        'verificationStatus': 'pending',
      });

      // Create the verification request
      await _firestore.collection('verification_requests').add({
        'houseId': houseId,
        'landlordId': landlordId,
        'shehia': shehia,
        'requestDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to request verification: $e');
    }
  }
}