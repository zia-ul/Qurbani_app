import 'dart:convert';

import 'package:Qurbani/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaymentService {
  static const _storage = FlutterSecureStorage();

  /**
   * Retrieves the current admin's payment settings and configuration
   *
   * Fetches payment-related settings for the authenticated admin including
   * payment method preferences, deadlines, and configuration options.
   * Used for displaying and managing payment settings in the admin interface.
   *
   * @return Map containing payment settings data
   * @throws Exception if fetch fails or admin is not authenticated
   */
  static Future<Map<String, dynamic>> getPaymentSettings() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception("Not authenticated");

    final res = await ApiClient.get(
      ApiClient.uri('admin/payment-settings'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: "Unable to load payment settings right now.",
        ),
        statusCode: res.statusCode,
      );
    }

    return ApiClient.decodeMap(
      res,
      fallbackMessage: "Unable to load payment settings right now.",
    );
  }

  /// Update admin payment settings
  static Future<void> updatePaymentSettings({
    required bool allowCod,
    required bool allowOnline,
    String? codDeadline, // ISO date string
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception("Not authenticated");

    final body = {
      "allow_cod": allowCod ? 1 : 0,
      "allow_online": allowOnline ? 1 : 0,
      if (codDeadline != null) "cod_deadline": codDeadline,
    };

    final res = await ApiClient.put(
      ApiClient.uri('admin/payment-settings'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: "Unable to update payment settings right now.",
        ),
        statusCode: res.statusCode,
      );
    }
  }
}
