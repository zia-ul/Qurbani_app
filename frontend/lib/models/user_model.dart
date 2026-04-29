class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? countryCode;
  final String role;
  final String? verificationStatus; // nullable

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.countryCode,
    required this.role,
    this.verificationStatus,
  });

  bool get isSuperAdmin => normalizeRole(role) == 'super_admin';

  static String normalizeRole(String? value) {
    return (value ?? '')
        .trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .toLowerCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      countryCode: json['country_code']?.toString(),
      role: json['role']?.toString() ?? '',
      verificationStatus:
          json['verification_status'] ?? json['admin_verification_status'],
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? countryCode,
    String? role,
    String? verificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}
