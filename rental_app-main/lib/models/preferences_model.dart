/// Each preferred area is stored as {name, lat?, lng?}.
/// lat/lng enable coordinate-based proximity filtering; name is the fallback.
class Preferences {
  List<Map<String, dynamic>> preferredAreas;
  double minPrice;
  double maxPrice;
  String propertyType;

  Preferences({
    required this.preferredAreas,
    required this.minPrice,
    required this.maxPrice,
    required this.propertyType,
  });

  Map<String, dynamic> toMap() {
    return {
      'preferredAreas': preferredAreas,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'propertyType': propertyType,
    };
  }

  factory Preferences.fromJson(Map<String, dynamic> data) {
    // Handle both old List<String> and new List<Map> formats gracefully.
    final raw = data['preferredAreas'] as List<dynamic>? ?? [];
    final areas = raw.map((item) {
      if (item is String) return <String, dynamic>{'name': item};
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).where((m) => m.containsKey('name')).toList();

    return Preferences(
      preferredAreas: areas,
      minPrice: (data['minPrice'] ?? 0.0).toDouble(),
      maxPrice: (data['maxPrice'] ?? 1000000.0).toDouble(),
      propertyType: data['propertyType'] ?? 'Room',
    );
  }
}
