// services/profile_service.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'api_client.dart';

class ProfileService {
  static const _storage = FlutterSecureStorage();

  /// Retrieves the authenticated user's profile information.
  ///
  /// Fetches comprehensive user profile data including personal details,
  /// contact information, and account settings. Used for profile display
  /// and user account management throughout the application.
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to load your profile right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to load your profile right now.',
    );
    return Map<String, dynamic>.from(body['profile']);
  }

  static Future<void> setUserCurrency(String currency) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    if (token == null) {
      throw const ApiException('User not authenticated');
    }

    final response = await ApiClient.put(
      ApiClient.uri('users/profile/currency'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'currency': currency}),
    );

    if (response.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        response,
        fallbackMessage: 'Failed to update currency',
      );
      throw ApiException(msg, statusCode: response.statusCode);
    }
  }

  /// UPDATE USER PROFILE
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to update profile',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }

  static Future<Map<String, dynamic>> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('users/email'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newEmail': newEmail,
      }),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to update email',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to update email',
    );
    final profile = Map<String, dynamic>.from(body['profile'] ?? body['user']);

    AuthService.updateCurrentUser(email: profile['email']?.toString());
    return profile;
  }

  static Future<Map<String, dynamic>> updatePhone({
    required String currentPassword,
    required String countryCode,
    required String newPhone,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('users/phone'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'countryCode': countryCode,
        'newPhone': newPhone,
      }),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to update phone number',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to update phone number',
    );
    final profile = Map<String, dynamic>.from(body['profile'] ?? body['user']);

    AuthService.updateCurrentUser(
      phone: profile['phone']?.toString(),
      countryCode: profile['country_code']?.toString(),
    );
    return profile;
  }

  // Currency update
  static Future<void> updateCurrency(String currency) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('users/profile/currency'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'currency': currency}),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to update currency',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }
}
