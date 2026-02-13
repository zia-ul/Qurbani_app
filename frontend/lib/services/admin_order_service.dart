// services/admin_order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class AdminOrderService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl = dotenv.env['BASE_URL'];



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

  /// SAVE / UPDATE ADMIN (VENDOR) SHARE SETUP
  static Future<void> saveShareSetup(Map<String, dynamic> payload) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.post(
      Uri.parse('$_baseUrl/admins/share-setup'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to save share setup');
    }
  }

  /// GET EXISTING SHARE SETUP (optional but recommended)
  static Future<Map<String, dynamic>?> getShareSetup() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/share-setup'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 404) return null;

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to fetch share setup');
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['data']);
  }

  /// MARK Cash ORDER AS PAID
  static Future<void> markCodOrderAsPaid(String orderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/$orderId/mark-paid'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to mark order as paid';
      throw Exception(msg);
    }
  }

  /// CANCEL ORDER (AUTO / MANUAL)
  static Future<void> cancelOrder(
    String orderId, {
    String reason = "COD deadline expired",
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');


    final res = await http.put(
      Uri.parse('$_baseUrl/orders/$orderId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reason': reason}),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to cancel order';
      throw Exception(msg);
    }
  }

  /// GET DELIVERY BOY DETAILS (after assignment)
  static Future<Map<String, dynamic>> getDeliveryBoyDetails(
    String orderId,
    String deliveryBoyId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/orders/$orderId/delivery-boy/$deliveryBoyId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to fetch delivery boy';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['deliveryBoy']);
  }

  /// GET SINGLE ORDER DETAILS
  static Future<Map<String, dynamic>> getAdminOrderById(String orderId) async {
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

  

  /// UPDATE ORDER - stepwise
  ///
  ///   // -------------------------------
  // STEP 1: Schedule Qurbani
  // -------------------------------
  static Future<void> updateSchedule(
    String orderId,
    DateTime qurbaniDateTime,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final formattedDt = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(qurbaniDateTime);

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/$orderId/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'qurbani_time': formattedDt}),
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ??
          'Failed to update qurbani schedule';
      throw Exception(msg);
    }
  }

  // -------------------------------
  // STEP 2: Save Meat Details
  // -------------------------------
  static Future<void> updateMeatDetails(
    String orderId, {
    required String meatWeight,
    required String bodyPartsDescription,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/animal-details/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'meat_weight': meatWeight,
        'body_parts_description': bodyPartsDescription,
      }),
    );

    if (res.statusCode != 200) {
      String msg = 'Failed to update meat details';

      try {
        final body = jsonDecode(res.body);
        msg = body['message'] ?? msg;

      } catch (_) {
        msg = res.body; // fallback for HTML/text
      }

      throw Exception(msg);
    }
  }

  // -------------------------------
  // STEP 3: Assign Delivery Boy
  // -------------------------------
  static Future<void> assignDeliveryBoy(
    String orderId,
    String deliveryPersonId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/orders/$orderId/delivery'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'delivery_person_id': deliveryPersonId}),
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to assign delivery';
      throw Exception(msg);
    }
  }
}
