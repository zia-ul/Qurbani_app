// services/rating_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RatingService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.4:3000/api';

  /// GET RATINGS AND ORDER DETAILS
  static Future<Map<String, dynamic>> getRatings(
    String orderId,
    String userId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/ratings/$orderId/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch ratings';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  /// SUBMIT RATINGS
  static Future<void> submitRatings(
    String orderId,
    String userId,
    List<Map<String, dynamic>> ratings,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.post(
      Uri.parse('$_baseUrl/ratings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'orderId': orderId,
        'userId': userId,
        'ratings': ratings,
      }),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to submit ratings';
      throw Exception(msg);
    }
  }
}
