/// This file contains the AdminService class, which handles API interactions
/// for admin-specific operations like fetching profiles, notifications, and dashboard statistics.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service class for handling admin-related API calls.
class AdminService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

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

  /**
   * Retrieves admin notifications for order updates and system alerts
   *
   * Fetches all pending notifications for the authenticated admin including
   * order status changes, new orders, and system notifications. Used for
   * real-time admin dashboard updates and notification management.
   *
   * @return List of notification objects with details and timestamps
   * @throws Exception if fetch fails or admin is not authenticated
   */
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

  /**
   * Retrieves comprehensive dashboard statistics for admin overview
   *
   * Fetches key performance indicators and metrics for the admin dashboard
   * including order counts, revenue figures, user statistics, and system
   * health metrics. Used for admin dashboard display and business intelligence.
   *
   * @return Map containing various dashboard statistics and KPIs
   * @throws Exception if fetch fails or admin is not authenticated
   */
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
