import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preferences_model.dart';

/// Fires whenever preferences are saved so any screen can reactively reload.
final prefChangedNotifier = ValueNotifier<int>(0);

/// Stores user preferences locally using SharedPreferences.
/// (Formerly used Firestore — now offline-first with local storage.)
class PreferencesService {
  static const _prefsKey = 'user_preferences';

  Future<void> savePreferences(String userId, Preferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_prefsKey}_$userId',
      jsonEncode(preferences.toMap()),
    );
    // Notify all listeners (home dashboard, explore screen, etc.)
    prefChangedNotifier.value++;
  }

  Future<Preferences> getPreferences(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_prefsKey}_$userId');
      if (raw != null) {
        return Preferences.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to defaults
    }
    return Preferences(
      preferredAreas: [],
      minPrice: 0.0,
      maxPrice: 1000000.0,
      propertyType: 'Room',
    );
  }
}
