// services/rating_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RatingService {
  static const _storage = FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

  static Future<Map<String, dynamic>> Function(
    String orderId,
    String userId,
  )? mockGetRatings;

  static Future<void> Function(
    String orderId,
    String userId,
    List<Map<String, dynamic>> ratings,
  )? mockSubmitRatings;

  /**
   * Retrieves existing ratings and order details for a specific order
   *
   * Fetches rating information and associated order details for display
   * in the rating/review interface. Used to show current ratings or
   * prepare the rating form for the user.
   *
   * @param orderId Unique identifier of the order to fetch ratings for
   * @param userId Unique identifier of the user requesting the ratings
   * @return Map containing rating data and order information
   * @throws Exception if fetch fails or user is not authenticated
   */
  static Future<Map<String, dynamic>> getRatings(
    String orderId,
    String userId,
  ) async {

     if (mockGetRatings != null) {
    return mockGetRatings!(orderId, userId);
  }

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

    if (mockSubmitRatings != null) {
    return mockSubmitRatings!(orderId, userId, ratings);
  }

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
