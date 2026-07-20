import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/house_model.dart';
import 'house_service.dart';

/// Tracks recently-viewed properties using local SharedPreferences.
/// (Formerly used Firestore — now offline-first with local storage.)
class RecentlyViewedService {
  static const _key = 'recently_viewed_ids';
  static const _maxItems = 10;

  final HouseService _houseService = HouseService();

  Future<void> addRecentlyViewedHouse(String houseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final List<String> ids = raw != null
          ? List<String>.from(jsonDecode(raw) as List)
          : [];

      ids.removeWhere((id) => id == houseId);
      ids.insert(0, houseId);
      if (ids.length > _maxItems) ids.removeLast();

      await prefs.setString(_key, jsonEncode(ids));
    } catch (_) {
      // Silently ignore
    }
  }

  Stream<List<HouseModel>> getRecentlyViewedStream() async* {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) {
        yield [];
        return;
      }
      final List<String> ids =
          List<String>.from(jsonDecode(raw) as List);
      if (ids.isEmpty) {
        yield [];
        return;
      }
      final houses = await _houseService.getHousesByIds(ids);
      // Maintain the recency order
      houses.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      yield houses;
    } catch (_) {
      yield [];
    }
  }
}
