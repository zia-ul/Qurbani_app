import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SlotService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.4:3000/api';

  static Future<Map<String, dynamic>> getSlots(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/slots/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch slots';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    return Map<String, dynamic>.from(data['slots']);
  }
}
