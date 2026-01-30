import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SuperAdminService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

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
    List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
      data['users'],
    );

    // Filter client-side if backend returns extra roles (optional)
    if (role == 'all') {
      users = users.where((u) {
        final r = u['role'];
        return r == 'admin' || r == 'pending' || r == 'user' || r == 'delivery';
      }).toList();
    }

    return users;
  }

  /// ===================== USER PROFILE =====================
  /// Fetch basic profile info (name, email, role, etc.)

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/users/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch user profile';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return Map<String, dynamic>.from(data['user']);
  }

  /// ===================== USER ORDERS =====================
  /// Fetch all orders taken by a user/admin

  static Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/users/$userId/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch user orders';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['orders']);
  }

  /// ===================== DELIVERY ORDERS =====================
  /// Fetch all orders assigned to a delivery person

  static Future<List<Map<String, dynamic>>> getDeliveryOrders(
    String deliveryPersonId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/delivery/$deliveryPersonId/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch delivery orders';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);

    return List<Map<String, dynamic>>.from(data['orders']);
  }

  /// Approve or reject a user/admin
  static Future<void> updateUser(
    String userId,
    String action, {
    String? reviewNote,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/superadmin/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action, // approve | reject
        if (reviewNote != null) 'review_note': reviewNote,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['message']);
    }
  }

  /// Fetch verification details for a specific admin
  static Future<Map<String, dynamic>?> getVerification(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/superadmin/verifications/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 404) {
      // No verification submitted yet
      return null;
    }

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch verification';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return Map<String, dynamic>.from(data['verification']);
  }
}
