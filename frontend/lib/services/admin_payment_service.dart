import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaymentService {
  static const _baseUrl = "http://192.168.1.4:3000/api/admin/payment-settings";
  static const _storage = FlutterSecureStorage();

  /// Get current admin payment settings
  static Future<Map<String, dynamic>> getPaymentSettings() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception("Not authenticated");

    final res = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? "Failed to fetch payment settings";
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
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

    final res = await http.put(
      Uri.parse(_baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ??
          "Failed to update payment settings";
      throw Exception(msg);
    }
  }
}
