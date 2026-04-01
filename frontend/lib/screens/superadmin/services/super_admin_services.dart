import 'dart:convert';

import 'package:Qurbani/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SuperAdminService {
  static const _storage = FlutterSecureStorage();

  /// Fetch users for superadmin
  /// If role = 'admin', keep the dashboard restricted to admin records only.
  static Future<List<Map<String, dynamic>>> getUsers(String role) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('superadmin/users', queryParameters: {'role': role}),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to load admin records right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load admin records right now.',
    );
    final rawUsers = data['users'];

    if (rawUsers is! List) {
      throw const ApiException(ApiClient.invalidResponseMessage);
    }

    var users = rawUsers
        .whereType<Map>()
        .map((user) => Map<String, dynamic>.from(user))
        .toList();

    if (role == 'admin') {
      users = users.where((user) {
        final userRole = (user['role'] ?? '').toString();
        return userRole == 'admin' || userRole == 'pending_admin';
      }).toList();
    }

    return users;
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('superadmin/users/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to fetch user profile',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to fetch user profile',
    );
    return Map<String, dynamic>.from(data['user']);
  }

  static Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('superadmin/users/$userId/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to fetch user orders',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to fetch user orders',
    );
    return List<Map<String, dynamic>>.from(data['orders']);
  }

  static Future<List<Map<String, dynamic>>> getDeliveryOrders(
    String deliveryPersonId,
  ) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('superadmin/delivery/$deliveryPersonId/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to fetch delivery orders',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to fetch delivery orders',
    );

    return List<Map<String, dynamic>>.from(data['orders']);
  }

  static Future<void> updateUser(
    String userId,
    String action, {
    String? reviewNote,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('superadmin/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        if (reviewNote != null) 'review_note': reviewNote,
      }),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to update admin review',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }

  static Future<Map<String, dynamic>?> getVerification(String adminId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('superadmin/verifications/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 404) {
      return null;
    }

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to fetch verification',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to fetch verification',
    );
    return Map<String, dynamic>.from(data['verification']);
  }
}
