import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// Fetch admin profile
  static Future<Map<String, dynamic>> getAdminProfile(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception(
        jsonDecode(res.body)['message'] ?? 'Failed to fetch admin',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  /// ✅ GET admin notifications (CORRECT)
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch notifications');
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['notifications']);
  }

  /// ✅ MARK notification as notified (CORRECT)
  static Future<void> markNotificationNotified(String id) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/notifications/$id/mark-notified'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to mark notification');
    }
  }

  /// Dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/dashboard-stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception(
        jsonDecode(res.body)['message'] ?? 'Failed to fetch stats',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }
}
