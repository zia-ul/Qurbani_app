import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// Fetch admin profile by adminId
  static Future<Map<String, dynamic>> getAdminProfile(String adminId) async {
    final token = await _storage.read(key: 'token'); // JWT auth

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/$adminId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch admin';
      throw Exception(msg);
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admin/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch notifications';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['notifications']);
  }

  static Future<void> markNotificationNotified(String notificationId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/admin/notifications/$notificationId/mark-notified'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to mark notification';
      throw Exception(msg);
    }
  }

  // Fetch dashboard stats (animals, orders, requests)
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admin/dashboard-stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch stats';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }
}
