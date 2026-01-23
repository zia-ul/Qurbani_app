import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeliveryService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/delivery/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch orders';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);

    print(data);
    return List<Map<String, dynamic>>.from(data['orders']);
  }

  static Future<Map<String, dynamic>> updateStatus(
    String orderId,
    String status,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/delivery/orders/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to update status';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<void> verifyCode(String orderId, String code) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/delivery/orders/$orderId/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code}),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to verify code';
      throw Exception(msg);
    }
  }

  static Future<List<String>> checkDeliveryNotifications() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/delivery/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];

    final List orders = jsonDecode(res.body)['orders'];
    return orders.map<String>((o) => o['id']).toList();
  }
}
