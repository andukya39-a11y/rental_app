import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/house_model.dart';

class HouseService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('properties');

  HouseModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    data['id'] = doc.id;
    return HouseModel.fromJson(data);
  }

  // ── Add a new house ────────────────────────────────────────────

  Future<void> addHouse(HouseModel house) async {
    final map = house.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    map['updatedAt'] = FieldValue.serverTimestamp();
    await _col.add(map);
  }

  // ── Get all houses with optional filters ───────────────────────

  Future<List<HouseModel>> getHouses({
    String? locationFilter,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? propertyTypeFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _col.where('isAvailable', isEqualTo: true);

      if (locationFilter != null && locationFilter.isNotEmpty) {
        query = query.where('location', isEqualTo: locationFilter);
      }
      if (minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: minPrice);
      }
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }
      if (minRooms != null) {
        query = query.where('bedrooms', isGreaterThanOrEqualTo: minRooms);
      }

      final snap = await query.get();
      var houses = snap.docs.map(_fromDoc).toList();

      if (propertyTypeFilter != null && propertyTypeFilter.isNotEmpty) {
        houses = houses
            .where((h) => h.propertyType == propertyTypeFilter)
            .toList();
      }

      return houses;
    } catch (_) {
      return [];
    }
  }

  // ── Stream variant ─────────────────────────────────────────────

  Stream<List<HouseModel>> getHousesStream({
    String? locationFilter,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    String? propertyTypeFilter,
  }) {
    Query<Map<String, dynamic>> query =
        _col.where('isAvailable', isEqualTo: true);

    if (locationFilter != null && locationFilter.isNotEmpty) {
      query = query.where('location', isEqualTo: locationFilter);
    }
    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    return query.snapshots().map((snap) {
      var houses = snap.docs.map(_fromDoc).toList();
      if (propertyTypeFilter != null && propertyTypeFilter.isNotEmpty) {
        houses = houses
            .where((h) => h.propertyType == propertyTypeFilter)
            .toList();
      }
      return houses;
    });
  }

  Stream<List<HouseModel>> getHousesForRecommendationsStream({int limit = 20}) {
    return _col
        .where('isAvailable', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  // ── Get house by ID ────────────────────────────────────────────

  Future<HouseModel?> getHouseById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  // ── Get houses by owner (current user) ─────────────────────────

  Future<List<HouseModel>> getHousesByUserId(String userId) async {
    try {
      final snap = await _col.where('userId', isEqualTo: userId).get();
      return snap.docs.map(_fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<HouseModel>> getHousesByUserIdStream(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  // ── Get houses by IDs ──────────────────────────────────────────

  Future<List<HouseModel>> getHousesByIds(List<String> houseIds) async {
    if (houseIds.isEmpty) return [];
    final results = await Future.wait(houseIds.map(getHouseById));
    return results.whereType<HouseModel>().toList();
  }

  // ── Update house ───────────────────────────────────────────────

  Future<void> updateHouse(HouseModel house) async {
    final map = house.toMap();
    map['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(house.id).update(map);
  }

  // ── Delete house ───────────────────────────────────────────────

  Future<void> deleteHouse(String id) async {
    await _col.doc(id).delete();
  }

  // ── Verify house (admin/sheha) ─────────────────────────────────

  Future<void> verifyHouse(String houseId, bool isVerified) async {
    await _col.doc(houseId).update({
      'isVerified': isVerified,
      'verificationStatus': isVerified ? 'verified' : 'rejected',
      'verificationDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Request verification ───────────────────────────────────────

  Future<void> requestShehaVerification(String houseId) async {
    await _col.doc(houseId).update({
      'verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('verification_requests').add({
      'propertyId': houseId,
      'requestedBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
