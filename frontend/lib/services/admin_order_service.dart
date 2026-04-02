// services/admin_order_service.dart
import 'dart:convert';
import 'package:Qurbani/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class AdminOrderService {
  static const _storage = FlutterSecureStorage();

  static List<Map<String, dynamic>> _dedupeOrders(List orders) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final item in orders) {
      final order = Map<String, dynamic>.from(item as Map);
      final key = (order['orderId'] ?? order['id'] ?? '').toString().trim();

      if (key.isNotEmpty && !seen.add(key)) {
        continue;
      }

      deduped.add(order);
    }

    return deduped;
  }

  static Future<String> _requireToken() async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      throw const ApiException('Admin not authenticated');
    }
    return token;
  }

  /// GET ALL ORDERS FOR THE AUTHENTICATED ADMIN
  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('orders/admin/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load orders right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load orders right now.',
    );
    final List orders = body['orders'] is List
        ? body['orders'] as List
        : const [];
    return _dedupeOrders(orders);
  }

  /// SAVE / UPDATE ADMIN (VENDOR) SHARE SETUP
  static Future<void> saveShareSetup(Map<String, dynamic> payload) async {
    final token = await _requireToken();

    final res = await ApiClient.post(
      ApiClient.uri('admins/share-setup'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to save your share setup right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  /// GET EXISTING SHARE SETUP (optional but recommended)
  static Future<Map<String, dynamic>?> getShareSetup() async {
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('admins/share-setup'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 404) return null;

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load your share setup right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    return ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load your share setup right now.',
    );
  }

  /// MARK Cash ORDER AS PAID
  static Future<void> markCodOrderAsPaid(String orderId) async {
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/mark-paid'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to mark the order as paid right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  /// CANCEL ORDER (AUTO / MANUAL)
  static Future<void> cancelOrder(
    String orderId, {
    String reason = "COD deadline expired",
  }) async {
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reason': reason}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to cancel the order right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  /// GET DELIVERY BOY DETAILS (after assignment)
  static Future<Map<String, dynamic>> getDeliveryBoyDetails(
    String orderId,
    String deliveryBoyId,
  ) async {
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('orders/$orderId/delivery-boy/$deliveryBoyId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load the delivery partner right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load the delivery partner right now.',
    );
    return Map<String, dynamic>.from(data['deliveryBoy'] ?? {});
  }

  /// GET SINGLE ORDER DETAILS
  static Future<Map<String, dynamic>> getAdminOrderById(String orderId) async {
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('orders/admin/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load the order details right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load the order details right now.',
    );
    return Map<String, dynamic>.from(data['order'] ?? {});
  }

  /// GET DELIVERY BOYS
  static Future<List<Map<String, dynamic>>> getDeliveryBoys() async {
    final token = await _requireToken();

    final res = await ApiClient.get(
      ApiClient.uri('delivery-boys'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load delivery partners right now.',
        ),
        statusCode: res.statusCode,
      );
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load delivery partners right now.',
    );
    final List deliveryBoys = body['deliveryBoys'] is List
        ? body['deliveryBoys'] as List
        : const [];
    return List<Map<String, dynamic>>.from(deliveryBoys);
  }

  /// UPDATE ORDER
  static Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to update the order right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  /// UPDATE ORDER - stepwise
  ///
  // -------------------------------
  // STEP 1: Schedule Qurbani
  // -------------------------------
  static Future<void> updateSchedule(
    String orderId,
    DateTime qurbaniDateTime,
  ) async {
    final token = await _requireToken();

    final formattedDt = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(qurbaniDateTime);

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'qurbani_time': formattedDt}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to update the qurbani schedule right now.',
        ),
        statusCode: res.statusCode,
      );
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
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/animal-details/$orderId'),
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
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to update meat details right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }

  // -------------------------------
  // STEP 3: Assign Delivery Boy
  // -------------------------------
  static Future<void> assignDeliveryBoy(
    String orderId,
    String deliveryPersonId,
  ) async {
    final token = await _requireToken();

    final res = await ApiClient.put(
      ApiClient.uri('orders/$orderId/delivery'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'delivery_person_id': deliveryPersonId}),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to assign delivery right now.',
        ),
        statusCode: res.statusCode,
      );
    }
  }
}
