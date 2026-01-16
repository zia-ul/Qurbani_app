import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SuperAdminService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// Fetch users for superadmin
  /// If role = 'all', only fetch admins, pending admins, users, delivery boys
  static Future<List<Map<String, dynamic>>> getUsers(String role) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/users?role=$role'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch users';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    List<Map<String, dynamic>> users =
        List<Map<String, dynamic>>.from(data['users']);

    // Filter client-side if backend returns extra roles (optional)
    if (role == 'all') {
      users = users.where((u) {
        final r = u['role'];
        return r == 'admin' || r == 'pending' || r == 'user' || r == 'delivery';
      }).toList();
    }

    return users;
  }

  /// Approve or reject a user/admin
  static Future<void> updateUser(String userId, String action) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/superadmin/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'action': action}),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to update user';
      throw Exception(msg);
    }
  }

  /// Fetch verification details for a specific admin
  static Future<Map<String, dynamic>> getVerification(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/verifications/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch verification';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return Map<String, dynamic>.from(data['verification']);
  }
}
