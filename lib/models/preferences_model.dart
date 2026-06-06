import 'package:cloud_firestore/cloud_firestore.dart';

class Preferences {
  List<String> preferredAreas;
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

  factory Preferences.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Preferences(
      preferredAreas: List<String>.from(data['preferredAreas'] ?? []),
      minPrice: (data['minPrice'] ?? 0.0).toDouble(),
      maxPrice: (data['maxPrice'] ?? 1000000.0).toDouble(),
      propertyType: data['propertyType'] ?? 'Room',
    );
  }
}
