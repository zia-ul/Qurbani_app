// services/rating_service.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class RatingService {
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> Function(String orderId, String userId)?
  mockGetRatings;

  static Future<void> Function(
    String orderId,
    String userId,
    List<Map<String, dynamic>> ratings,
  )?
  mockSubmitRatings;

  /*
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
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('ratings/$orderId/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to load ratings right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    return ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load ratings right now.',
    );
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
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.post(
      ApiClient.uri('ratings'),
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
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to submit your rating right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }
}
