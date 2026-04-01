import 'dart:convert';
import 'package:Qurbani/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OrderService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  static Future<Map<String, dynamic>> Function(String orderId)?
  mockGetOrderDetails;

  static Future<void> Function(String orderId)? mockCancelOrder;

  /**
   * Places a new order for Qurbani animal shares
   *
   * Creates a comprehensive order including multiple shareholders, payment method,
   * and total amount calculation. This is the primary order creation endpoint
   * used by the order placement flow.
   *
   * @param userId ID of the user placing the order
   * @param adminId ID of the admin/vendor fulfilling the order
   * @param paymentMethod Payment method ('Cash' or 'Online')
   * @param shareholders List of shareholder details with animal portions
   * @param totalAmount Total order amount in selected currency
   * @return Map containing order creation response with order ID and details
   * @throws Exception if order placement fails or user is not authenticated
   */
  static Future<Map<String, dynamic>> placeOrder({
    required String userId,
    required String adminId,
    required String paymentMethod,
    required String paymentStatus,
    required List<Map<String, dynamic>> shareholders,
    required double totalAmount,
  }) async {

    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await ApiClient.post(
      ApiClient.uri('orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'adminId': adminId,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus, // SEND TO BACKEND
        'shareholders': shareholders,
        'totalAmount': totalAmount,
      }),
    );

    if (res.statusCode != 201) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to place your order right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    return ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to place your order right now.',
    );
  }

  static Future<String> _requireToken({
    String message = 'Not authenticated',
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      throw ApiException(message);
    }

    return token;
  }

  // Fetch barcode for a specific animal order
  static Future<String> getOrderBarcode(String orderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');
    // final res = await http.get(Uri.parse('$_baseUrl/orders/$orderId/barcode'));
    final res = await http.get(
      Uri.parse('$_baseUrl/orders/$orderId/barcode'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['barcode']; // should be a string
    } else {
      throw Exception('Failed to fetch barcode');
    }
  }

  /// GET ANIMALS FOR ADMIN
  static Future<Map<String, dynamic>> getAnimals(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/$adminId/animals'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch animals';
      throw Exception(msg);
    }

    return jsonDecode(res.body);
  }

  /// Update Processing Status (Add this to OrderService)
  static Future<void> updateOrderStatus(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse(
        '$_baseUrl/orders/admin/$orderId/status',
      ), // Ensure route matches backend
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to update status';
      throw Exception(msg);
    }
  }

  static Future<void> updatePaymentSuccess(
    String orderId,
    String paymentId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/payment-success'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'paymentId': paymentId}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to update the payment status right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  /// GET ALL ORDERS FOR CURRENT USER
  static Future<List<Map<String, dynamic>>> getUserOrders() async {
    final token = await _requireToken(message: 'User not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('orders/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load your bookings right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load your bookings right now.',
    );
    final List data = body['orders'] is List ? body['orders'] as List : [];
    return List<Map<String, dynamic>>.from(data);
  }

  /// GET SINGLE ORDER DETAILS
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final token = await _requireToken(message: 'User not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load this order right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load this order right now.',
    );
    return Map<String, dynamic>.from(body['order']);
  }

  static Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    if (mockGetOrderDetails != null) {
      return mockGetOrderDetails!(orderId);
    }
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load this order right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load this order right now.',
    );
    return Map<String, dynamic>.from(data['order']);
  }

  static Future<void> cancelOrder(String orderId) async {
    if (mockCancelOrder != null) {
      return mockCancelOrder!(orderId);
    }
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to cancel this order right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getAnimalOrders(
    String animalId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/animals/$animalId/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final msg = body['message'] ?? 'Failed to fetch orders';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);

    // 🔥 IMPORTANT FIX HERE
    if (data == null || data['shareholders'] == null) {
      return [];
    }

    return List<Map<String, dynamic>>.from(data['shareholders']);
  }
}

// ADMIN ORDER SERVICE

class AdminOrderService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  /**
   * Retrieves detailed order information for admin review
   *
   * Fetches comprehensive order data including sensitive information
   * only accessible to administrators. Used for order management
   * and detailed order inspection.
   *
   * @param orderId Unique identifier of the order to retrieve
   * @return Map containing complete order details with admin-level data
   * @throws Exception if order not found or admin authentication fails
   */
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
  static Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse(
        '$_baseUrl/orders/admin/$orderId',
      ), // Add this route if needed (see below)
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
