import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeliveryService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

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

  /**
   * Updates the delivery status of a specific order
   *
   * Allows delivery personnel to update order status during delivery process
   * (e.g., 'picked_up', 'out_for_delivery', 'delivered'). Critical for tracking
   * delivery progress and notifying customers.
   *
   * @param orderId Unique identifier of the order to update
   * @param status New delivery status to set
   * @return Map containing updated order information
   * @throws Exception if update fails or delivery person is not authenticated
   */
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
