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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      verificationStatus: json['verification_status'], // may be null
    );
  }
}
