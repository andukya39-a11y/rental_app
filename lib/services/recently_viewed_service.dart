import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/house_model.dart';

class RecentlyViewedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addRecentlyViewedHouse(String houseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = _firestore.collection('users').doc(user.uid);
      final doc = await userDoc.get();
      final List<dynamic> recent = doc.data()?['recentlyViewed'] ?? [];

      recent.removeWhere((item) => item['houseId'] == houseId);

      recent.insert(0, {
        'houseId': houseId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (recent.length > 10) {
        recent.removeLast();
      }

      await userDoc.update({'recentlyViewed': recent});
    } catch (e) {
      // Silently log in production
    }
  }

  Stream<List<HouseModel>> getRecentlyViewedStream() {
    return FirebaseAuth.instance
        .authStateChanges()
        .asyncExpand<List<HouseModel>>((user) {
      if (user == null) {
        return Stream.value(<HouseModel>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncMap<List<HouseModel>>((doc) async {
        final recent = doc.data()?['recentlyViewed'] as List<dynamic>? ?? [];
        if (recent.isEmpty) {
          return <HouseModel>[];
        }
        final houseIds = recent
            .take(10)
            .map((e) => e['houseId'] as String)
            .toList();
        if (houseIds.isEmpty) {
          return <HouseModel>[];
        }
        final housesSnapshot = await _firestore
            .collection('houses')
            .where(FieldPath.documentId, whereIn: houseIds)
            .get();
        final houses = housesSnapshot.docs
            .map((doc) => HouseModel.fromDocument(doc))
            .toList();
        houses.sort((a, b) {
          final idxA = houseIds.indexOf(a.id);
          final idxB = houseIds.indexOf(b.id);
          return idxA.compareTo(idxB);
        });
        return houses;
      });
    });
  }
}
