class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? nationalId;
  final String? profilePhoto;
  final String roleName;
  final bool isVerified;
  final String status;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.nationalId,
    this.profilePhoto,
    required this.roleName,
    required this.isVerified,
    required this.status,
  });

  int get roleId {
    switch (roleName) {
      case 'Super Admin': return 1;
      case 'Technical Admin': return 2;
      case 'Owner': return 3;
      case 'Tenant': return 4;
      case 'Moderator': return 5;
      default: return 4;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? json['phoneNumber'] as String?,
      nationalId: json['national_id'] as String? ?? json['nationalId'] as String?,
      profilePhoto: json['profile_photo'] as String? ?? json['profilePhoto'] as String?,
      roleName: json['role_name'] as String? ?? json['roleName'] as String? ?? 'Tenant',
      isVerified: json['is_verified'] == true || json['isVerified'] == true,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'nationalId': nationalId,
      'profilePhoto': profilePhoto,
      'roleName': roleName,
      'isVerified': isVerified,
      'status': status,
    };
  }

  bool get isAdmin =>
      ['Super Admin', 'Technical Admin', 'Moderator'].contains(roleName);
  bool get isOwner => roleName == 'Owner';
  bool get isTenant => roleName == 'Tenant';
  bool get isSheha => roleName == 'Sheha';
  bool get isSuperAdmin => roleName == 'Super Admin';

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? nationalId,
    String? profilePhoto,
    String? roleName,
    bool? isVerified,
    String? status,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationalId: nationalId ?? this.nationalId,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      roleName: roleName ?? this.roleName,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
    );
  }
}
