import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserService {
  static final String? _baseUrl =  dotenv.env['BASE_URL'];
  static const _storage = FlutterSecureStorage();

  /**
   * Retrieves the authenticated user's profile information
   *
   * Fetches comprehensive user profile data including personal information,
   * contact details, and account settings. Used for profile display and
   * user account management.
   *
   * @return Map containing user profile data
   * @throws Exception if profile fetch fails or user is not authenticated
   */
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

  /**
   * Retrieves list of available delivery personnel
   *
   * Fetches all users with 'delivery' role for order assignment and
   * delivery coordination. Used by admins and order management system
   * to assign delivery tasks and track delivery personnel.
   *
   * @return List of delivery boy profiles with contact information
   * @throws Exception if fetch fails or user is not authenticated
   */
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
