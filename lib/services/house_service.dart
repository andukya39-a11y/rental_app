import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/utils/notification_service.dart';
import 'package:rental_app/models/preferences_model.dart';
import 'package:rental_app/services/preferences_service.dart';

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
      _notificationService.showNotification(
          'New house added: ${houseWithUserId.title} in ${houseWithUserId.location}');
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

      if (propertyTypeFilter != null &&
          propertyTypeFilter.isNotEmpty &&
          propertyTypeFilter != 'All') {
        query = query.where('propertyType', isEqualTo: propertyTypeFilter);
      }

      // For rooms filtering, we'll filter bedrooms + bathrooms >= minRooms
      // Note: Firestore doesn't support complex queries easily, so we'll get all and filter in Dart
      // For a production app, you might want to denormalize or use a different approach

      final snapshot = await query.get();
      List<HouseModel> houses =
          snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();

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

    if (propertyTypeFilter != null &&
        propertyTypeFilter.isNotEmpty &&
        propertyTypeFilter != 'All') {
      query = query.where('propertyType', isEqualTo: propertyTypeFilter);
    }

    return query.snapshots().map((snapshot) {
      List<HouseModel> houses =
          snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();

      // Apply rooms filter in Dart
      if (minRooms != null) {
        houses = houses.where((house) {
          return (house.bedrooms + house.bathrooms) >= minRooms;
        }).toList();
      }

      return houses;
    });
  }

  // Get a limited set of houses for recommendations, scored by user preferences
  Stream<List<HouseModel>> getHousesForRecommendationsStream({int limit = 50}) {
    return FirebaseAuth.instance
        .authStateChanges()
        .asyncExpand((user) async* {
          if (user == null) {
            yield [];
            return;
          }
          final preferencesService = PreferencesService();
          final preferences = await preferencesService.getPreferences(user.uid);
          yield* _firestore
              .collection(_collectionName)
              .limit(limit)
              .snapshots()
              .map((snapshot) => snapshot.docs
                  .map((doc) => HouseModel.fromDocument(doc))
                  .toList())
              .map((houses) => scoreHouses(houses, preferences));
        });
  }

  /// Get a stream of houses scored by user preferences.
  /// Returns houses sorted by relevance score (highest first), limited by [limit].
  Stream<List<HouseModel>> getRecommendedHousesStream({
    required Preferences preferences,
    int limit = 20,
  }) {
    return _firestore
        .collection(_collectionName)
        .limit(50) // fetch more to score
        .snapshots()
        .map((snapshot) {
      final houses =
          snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();
      return scoreHouses(houses, preferences);
    }).map((scored) {
      if (scored.length > limit) {
        return scored.sublist(0, limit);
      }
      return scored;
    });
  }

  /// Score houses by user preferences and return sorted (best first).
  List<HouseModel> scoreHouses(
      List<HouseModel> houses, Preferences preferences) {
    final scored = <_ScoredHouse>[];
    for (final house in houses) {
      final score = _calculateScore(house, preferences);
      scored.add(_ScoredHouse(house, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.house).toList();
  }

  /// Sort houses by distance from a given GPS coordinate (nearest first).
  List<HouseModel> sortHousesByDistance(
    List<HouseModel> houses, {
    required double userLat,
    required double userLng,
  }) {
    final sorted = List<HouseModel>.from(houses);
    sorted.sort((a, b) {
      final distA =
          _haversineDistance(userLat, userLng, a.latitude, a.longitude);
      final distB =
          _haversineDistance(userLat, userLng, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });
    return sorted;
  }

  /// Get houses near a location using GPS coordinates, sorted by distance.
  Stream<List<HouseModel>> getHousesNearMeStream({
    required double userLat,
    required double userLng,
    double maxRadiusKm = 50.0,
  }) {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      final houses =
          snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();
      // Filter to only houses with coordinates within radius
      final nearby = houses.where((h) {
        if (h.latitude == null || h.longitude == null) return false;
        final dist =
            _haversineDistance(userLat, userLng, h.latitude!, h.longitude!);
        return dist <= maxRadiusKm;
      }).toList();
      // Sort by distance
      return sortHousesByDistance(nearby, userLat: userLat, userLng: userLng);
    });
  }

  /// Haversine distance in km between two GPS points.
  double _haversineDistance(
      double lat1, double lng1, double? lat2, double? lng2) {
    if (lat2 == null || lng2 == null) return double.infinity;
    const double earthRadius = 6371.0; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a = _sinSquared(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sinSquared(dLng / 2);
    final double c = 2 * _asin(_sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (3.141592653589793 / 180);
  double _sinSquared(double x) {
    final s = _sin(x);
    return s * s;
  }

  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  double _asin(double x) => x + (x * x * x) / 6 + (3 * x * x * x * x * x) / 40;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x / 2;
    for (int i = 0; i < 10; i++) {
      z = (z + x / z) / 2;
    }
    return z;
  }

  double _calculateScore(HouseModel house, Preferences preferences) {
    double score = 0.0;

    // Location match: if house.location is in preferredAreas
    if (house.location.isNotEmpty &&
        preferences.preferredAreas.contains(house.location)) {
      score += 30.0;
    }

    // Price match: if house.price is between minPrice and maxPrice
    if (house.price >= preferences.minPrice &&
        house.price <= preferences.maxPrice) {
      score += 30.0;
    }

    // Property type match
    if (house.propertyType != null &&
        house.propertyType!.isNotEmpty &&
        house.propertyType == preferences.propertyType) {
      score += 20.0;
    }

    // Availability
    if (house.isAvailable) {
      score += 10.0;
    }

    // Verification
    if (house.isVerified) {
      score += 10.0;
    }

    return score;
  }

  // Get multiple houses by their IDs
  Future<List<HouseModel>> getHousesByIds(List<String> houseIds) async {
    if (houseIds.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where(FieldPath.documentId, whereIn: houseIds)
          .get();
      return snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();
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

      return snapshot.docs.map((doc) => HouseModel.fromDocument(doc)).toList();
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
      final houseDoc =
          await _firestore.collection(_collectionName).doc(houseId).get();
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

class _ScoredHouse {
  final HouseModel house;
  final double score;
  _ScoredHouse(this.house, this.score);
}
