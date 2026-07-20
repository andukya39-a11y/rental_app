class VerificationRequestModel {
  final String id;
  final String houseId;
  final String landlordId;
  final String shehia;
  final DateTime? requestDate;

  VerificationRequestModel({
    required this.id,
    required this.houseId,
    required this.landlordId,
    required this.shehia,
    this.requestDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'landlordId': landlordId,
      'shehia': shehia,
      if (requestDate != null) 'requestDate': requestDate!.toIso8601String(),
    };
  }

  factory VerificationRequestModel.fromJson(
      Map<String, dynamic> data, {String id = ''}) {
    return VerificationRequestModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      houseId: data['houseId'] ?? '',
      landlordId: data['landlordId'] ?? '',
      shehia: data['shehia'] ?? '',
      requestDate: data['requestDate'] != null
          ? DateTime.tryParse(data['requestDate'].toString())
          : null,
    );
  }
}
