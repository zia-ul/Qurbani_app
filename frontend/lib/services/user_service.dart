import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  static const _baseUrl = 'http://192.168.1.6:3000/api';
  static const _storage = FlutterSecureStorage();

  /// Fetch logged-in user profile
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _storage.read(key: 'token');

    final res = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile');
    }

    return jsonDecode(res.body);
  }

  /// Update profile
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final token = await _storage.read(key: 'token');

    final res = await http.put(
      Uri.parse('$_baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Update failed';
      throw Exception(msg);
    }
  }

  /// Fetch delivery boys (users with role 'delivery')
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
}
