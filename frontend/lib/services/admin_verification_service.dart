import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminVerificationService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api'; 

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch profile';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body)['profile']);
  }

  static Future<void> submitVerification(Map<String, dynamic> data) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.post(
      Uri.parse('$_baseUrl/admin/verification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to submit verification';
      throw Exception(msg);
    }
  }

  static Future<String?> getVerificationStatus() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/admin/verification/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch status';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return data['status'];
  }
}