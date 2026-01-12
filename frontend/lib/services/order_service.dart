import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OrderService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// PLACE ORDER
  /// Expects:
  /// userId, adminId, paymentMethod ('Cash'/'Online'), shareholders (List<Map<String,dynamic>>)
  static Future<void> placeOrder({
    required String userId,
    required String adminId,
    required String paymentMethod,
    required List<Map<String, dynamic>> shareholders,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('User not authenticated');

    final res = await http.post(
      Uri.parse('$_baseUrl/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'adminId': adminId,
        'paymentMethod': paymentMethod,
        'shareholders': shareholders,
      }),
    );

    if (res.statusCode != 201) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to place order';
      throw Exception(msg);
    }
  }

  /// GET ALL ORDERS FOR CURRENT USER
  static Future<List<Map<String, dynamic>>> getUserOrders() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('User not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch orders';
      throw Exception(msg);
    }

    final List data = jsonDecode(res.body)['orders'];
    return List<Map<String, dynamic>>.from(data);
  }

  /// GET SINGLE ORDER DETAILS
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('User not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch order';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['order']);
  }
}


class AdminOrderService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// GET SINGLE ORDER DETAILS (for admin)
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/admin/$orderId'), 
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch order';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['order']);
  }

  /// UPDATE ORDER (for admin)
  static Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/admin/$orderId'),  // Add this route if needed (see below)
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to update order';
      throw Exception(msg);
    }
  }

  /// GET ALL ORDERS FOR ADMIN
  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/admin/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch orders';
      throw Exception(msg);
    }

    final List data = jsonDecode(res.body)['orders'];
    return List<Map<String, dynamic>>.from(data);
  }
}
