// services/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// GET USER PROFILE
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print(res.body);

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch profile';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['profile']);
  }

  /// UPDATE USER PROFILE
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to update profile';
      throw Exception(msg);
    }
  }

  // Currency update
  static Future<void> updateCurrency(String currency) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/profile/currency'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'currency': currency}),
    );

    if (res.statusCode != 200) {
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to update currency';
      throw Exception(msg);
    }
  }
}
