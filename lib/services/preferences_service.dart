import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/preferences_model.dart';

class PreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves user preferences to the 'users/{userId}' document.
  /// Uses [set] with [SetOptions.merge] to avoid overwriting other fields
  /// on the same document (e.g. recentlyViewed).
  Future<void> savePreferences(String userId, Preferences preferences) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(preferences.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save preferences: $e');
    }
  }

  Future<Preferences> getPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return Preferences.fromDocument(doc);
      } else {
        // Return default preferences if none exist
        return Preferences(
          preferredAreas: [],
          minPrice: 0.0,
          maxPrice: 1000000.0, // A high default max
          propertyType: 'Room',
        );
      }
    } catch (e) {
      throw Exception('Failed to get preferences: $e');
    }
  }
}
