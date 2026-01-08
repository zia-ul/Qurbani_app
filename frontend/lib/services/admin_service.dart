import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  /// Fetch admin profile by adminId
  static Future<Map<String, dynamic>> getAdminProfile(String adminId) async {
    final token = await _storage.read(key: 'token'); // JWT auth

    final res = await http.get(
      Uri.parse('$_baseUrl/admins/$adminId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch admin';
      throw Exception(msg);
    }
  }
}
