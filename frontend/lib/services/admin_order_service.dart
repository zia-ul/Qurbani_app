// services/admin_order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminOrderService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl =
      'http://192.168.1.6:3000/api'; // Adjust to your server URL

  /// GET ALL ORDERS FOR THE AUTHENTICATED ADMIN
  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Admin not authenticated');

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

  /// GET SINGLE ORDER DETAILS
  static Future<Map<String, dynamic>> getAdminOrderById(String orderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/admin/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(res.body);
    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch order';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['order']);
  }

  /// GET DELIVERY BOYS
  static Future<List<Map<String, dynamic>>> getDeliveryBoys() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/delivery-boys'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch delivery boys';
      throw Exception(msg);
    }

    final List data = jsonDecode(res.body)['deliveryBoys'];
    return List<Map<String, dynamic>>.from(data);
  }

  /// UPDATE ORDER
  static Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/$orderId'),
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
}
