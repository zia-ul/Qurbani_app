class UserModel {
  final String id;
  final String name;
  final String role;
  final String? verificationStatus; // nullable

  UserModel({
    required this.id,
    required this.name,
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
      role: json['role']?.toString() ?? '',
      verificationStatus:
          json['verification_status'] ?? json['admin_verification_status'],
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? role,
    String? verificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}
