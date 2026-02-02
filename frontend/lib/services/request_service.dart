// services/request_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RequestService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  /// SUBMIT SPECIAL REQUEST
  static Future<void> submitRequest(
    String orderId,
    String userId,
    String title,
    String description,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');
    print("requests.........$orderId, $userId, $title, $description");
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

  static Future<List<Map<String, dynamic>>> Function()? mockGetUserRequests;

  /**
   * Retrieves all special requests submitted by the authenticated user
   *
   * Fetches the user's request history including pending, replied, and closed
   * requests. Used for displaying request status and history in the user interface.
   *
   * @return List of request objects with details and status information
   * @throws Exception if fetch fails or user is not authenticated
   */
  static Future<List<Map<String, dynamic>>> getUserRequests() async {
    if (mockGetUserRequests != null) {
      return mockGetUserRequests!();
    }

    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/special-requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Failed to fetch requests';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body);
    print(data);
    return List<Map<String, dynamic>>.from(data['requests']);
  }
}
