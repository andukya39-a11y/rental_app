import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/house_model.dart';
import 'api_service.dart';

class PropertyService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('properties');

  HouseModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    data['id'] = doc.id;
    return HouseModel.fromJson(data);
  }

  // ── List properties with optional filters ──────────────────────

  Future<ApiResponse> getProperties({
    String? search,
    String? location,
    String? categoryId,
    double? priceMin,
    double? priceMax,
    int? rooms,
    bool? selfContained,
    String? availabilityStatus,
    String sort = 'latest',
    int page = 1,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _col;

      if (availabilityStatus != null) {
        query = query.where('isAvailable',
            isEqualTo: availabilityStatus == 'available');
      }
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }
      if (priceMin != null) {
        query = query.where('price', isGreaterThanOrEqualTo: priceMin);
      }
      if (priceMax != null) {
        query = query.where('price', isLessThanOrEqualTo: priceMax);
      }
      if (rooms != null) {
        query = query.where('bedrooms', isGreaterThanOrEqualTo: rooms);
      }

      final snap = await query.get();
      var houses = snap.docs.map(_fromDoc).toList();

      // Client-side search filter
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        houses = houses
            .where((h) =>
                h.title.toLowerCase().contains(q) ||
                h.location.toLowerCase().contains(q) ||
                h.description.toLowerCase().contains(q))
            .toList();
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        houses = houses
            .where((h) => h.propertyType == categoryId)
            .toList();
      }

      // Sort
      if (sort == 'price_asc') {
        houses.sort((a, b) => a.price.compareTo(b.price));
      } else if (sort == 'price_desc') {
        houses.sort((a, b) => b.price.compareTo(a.price));
      } else {
        houses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return ApiResponse.ok(data: houses);
    } catch (e) {
      return ApiResponse.error('Failed to load properties: $e');
    }
  }

  // ── Get single property ────────────────────────────────────────

  Future<ApiResponse> getProperty(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return ApiResponse.error('Property not found.');
      return ApiResponse.ok(data: _fromDoc(doc));
    } catch (e) {
      return ApiResponse.error('Failed to load property: $e');
    }
  }

  // ── Create property ────────────────────────────────────────────

  Future<ApiResponse> createProperty(Map<String, dynamic> data) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.error('Not logged in.');

      data['userId'] = uid;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data.putIfAbsent('isAvailable', () => true);
      data.putIfAbsent('isVerified', () => false);
      data.putIfAbsent('status', () => 'pending');
      data.putIfAbsent('verificationStatus', () => 'pending');

      final ref = await _col.add(data);
      return ApiResponse.ok(data: {'id': ref.id}, message: 'Property created.');
    } catch (e) {
      return ApiResponse.error('Failed to create property: $e');
    }
  }

  // ── Upload property image to Firebase Storage ──────────────────

  Future<ApiResponse> uploadPropertyImage(String propertyId, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last;
      final fileName =
          'property_images/$propertyId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _col.doc(propertyId).update({
        'imageUrl': url,                           // singular — kept for backward compat
        'imageUrls': FieldValue.arrayUnion([url]), // array — used by verification cards
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ApiResponse.ok(data: {'url': url}, message: 'Image uploaded.');
    } catch (e) {
      return ApiResponse.error('Image upload failed: $e');
    }
  }

  // ── Update property ────────────────────────────────────────────

  Future<ApiResponse> updateProperty(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _col.doc(id).update(data);
      return ApiResponse.ok(message: 'Property updated.');
    } catch (e) {
      return ApiResponse.error('Failed to update property: $e');
    }
  }

  // ── Delete property ────────────────────────────────────────────

  Future<ApiResponse> deleteProperty(String id) async {
    try {
      await _col.doc(id).delete();
      return ApiResponse.ok(message: 'Property deleted.');
    } catch (e) {
      return ApiResponse.error('Failed to delete property: $e');
    }
  }

  // ── Get owner's own listings ───────────────────────────────────

  Future<ApiResponse> getMyListings({int page = 1}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.ok(data: []);

      final snap = await _col
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      final houses = snap.docs.map(_fromDoc).toList();
      return ApiResponse.ok(data: houses);
    } catch (e) {
      return ApiResponse.error('Failed to load listings: $e');
    }
  }

  // ── Get property categories (static list) ─────────────────────

  Future<ApiResponse> getCategories() async {
    const categories = [
      {'id': 'apartment', 'category_name': 'Apartment'},
      {'id': 'house', 'category_name': 'House'},
      {'id': 'villa', 'category_name': 'Villa'},
      {'id': 'room', 'category_name': 'Room'},
      {'id': 'studio', 'category_name': 'Studio'},
      {'id': 'office', 'category_name': 'Office'},
      {'id': 'shop', 'category_name': 'Shop'},
    ];
    return ApiResponse.ok(data: categories);
  }

  // ── Increment view count ───────────────────────────────────────

  Future<void> incrementView(String id) async {
    try {
      await _col.doc(id).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }
}
