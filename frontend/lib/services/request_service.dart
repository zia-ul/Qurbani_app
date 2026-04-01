// services/request_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class RequestService {
  static const _storage = FlutterSecureStorage();

  /// SUBMIT SPECIAL REQUEST
  static Future<void> submitRequest(
    String orderId,
    String userId,
    String title,
    String description,
  ) async {
    final requestUri = ApiClient.uri('requests');

    if (kDebugMode) {
      debugPrint(
        '[RequestService] submitRequest uri=$requestUri orderId=$orderId userId=$userId titleLength=${title.trim().length} descriptionLength=${description.trim().length}',
      );
    }

    if (orderId.trim().isEmpty) {
      throw const ApiException(
        'We could not identify this order. Please open it again and try.',
      );
    }

    if (userId.trim().isEmpty) {
      throw const ApiException('Not authenticated');
    }

    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.post(
      requestUri,
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

    if (kDebugMode) {
      debugPrint(
        '[RequestService] submitRequest status=${res.statusCode} body=${res.body}',
      );
    }

    if (res.statusCode != 201) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to submit your special request right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }

  static Future<List<Map<String, dynamic>>> Function()? mockGetUserRequests;

  /*
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
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('special-requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to load your special requests right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load your special requests right now.',
    );
    final requests = data['requests'];

    if (requests is! List) {
      throw const ApiException(ApiClient.invalidResponseMessage);
    }

    return requests
        .whereType<Map>()
        .map((request) => Map<String, dynamic>.from(request))
        .toList();
  }
}
