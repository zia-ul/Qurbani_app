// services/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

  /**
   * Retrieves the authenticated user's profile information
   *
   * Fetches comprehensive user profile data including personal details,
   * contact information, and account settings. Used for profile display
   * and user account management throughout the application.
   *
   * @return Map containing user profile data
   * @throws Exception if profile fetch fails or user is not authenticated
   */
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

  static Future<void> setUserCurrency(String currency) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/users/currencies'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'currency': currency}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update currency: ${response.body}');
    }
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
