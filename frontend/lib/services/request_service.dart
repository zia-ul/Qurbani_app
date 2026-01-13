// services/request_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RequestService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api'; // Adjust to your server

  /// SUBMIT SPECIAL REQUEST
  static Future<void> submitRequest(String orderId, String userId, String title, String description) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');
print("...........$orderId, $userId, $title, $description");
    final res = await http.post(
      Uri.parse('$_baseUrl/requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'orderId': orderId,
        'userId': userId,
        'title': title,
        'description': description,
      }),
    );

    if (res.statusCode != 201) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to submit request';
      throw Exception(msg);
    }
  }
}