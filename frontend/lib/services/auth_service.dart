import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../models/user_model.dart';
import 'api_client.dart';

/*
 * AuthService Class
 *
 * Singleton service class that provides authentication functionality.
 * Handles communication with authentication endpoints and manages user sessions.
 */
class AuthService {
  // Secure storage instance for JWT tokens and user data
  static const _storage = FlutterSecureStorage();

  static Future<void> Function(String current, String next)? mockChangePassword;

  static Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  // GET CURRENT USER (with token)
  static Future<UserModel?> getCurrentUser() async {
    final token = await _storage.read(key: 'token');

    if (token == null) {
      return null;
    }

    final res = await ApiClient.get(
      ApiClient.uri('auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to fetch current user',
      );
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'userId');
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final decoded = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Failed to fetch current user',
    );

    if (decoded['user'] == null) {
      return null;
    }

    return UserModel.fromJson(decoded['user']);
  }

  /*
   * Registers a new user account
   *
   * Sends user registration data to /auth/register endpoint.
   * Handles comprehensive user information including personal details,
   * contact information, and role preferences.
   *
   * @param data Map containing user registration data (name, email, password, etc.)
   * @throws Exception if registration fails with server error message
   */
  static Future<void> register(Map<String, dynamic> data) async {
    final res = await ApiClient.post(
      ApiClient.uri('auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Registration failed',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }

  static Future<UserModel> login(Map<String, dynamic> data) async {
    final res = await ApiClient.post(
      ApiClient.uri('auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(res, fallbackMessage: 'Login failed');
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final body = ApiClient.decodeMap(res, fallbackMessage: 'Login failed');
    final token = body['token'];
    final user = body['user'];

    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'userId', value: user['id'].toString());

    /// 🔥 IMPORTANT — Link OneSignal user
    await OneSignal.login(user['id'].toString());

    /// 🔥 Register device immediately
    await _registerDeviceIfAvailable(token, user);

    /// 🔥 Listen for future subscription changes
    _attachSubscriptionObserver(token, user);

    return UserModel.fromJson(user);
  }

  static Future<void> _registerDeviceIfAvailable(
    String token,
    dynamic user,
  ) async {
    final subscription = OneSignal.User.pushSubscription;

    final subscriptionId = subscription.id;
    final optedIn = subscription.optedIn == true;

    if (subscriptionId != null && optedIn) {
      await _registerDevice(token, user, subscriptionId);
    }
  }

  static void _attachSubscriptionObserver(String token, dynamic user) {
    OneSignal.User.pushSubscription.addObserver((state) async {
      final id = state.current.id;
      final optedIn = state.current.optedIn == true;

      if (id != null && optedIn) {
        await _registerDevice(token, user, id);
      }
    });
  }

  static Future<void> _registerDevice(
    String token,
    dynamic user,
    String subscriptionId,
  ) async {
    try {
      await http.post(
        ApiClient.uri('notifications/save-device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': user['id'],
          'role': user['role'],
          'subscription_id': subscriptionId,
        }),
      );
    } catch (_) {}
  }

  /*
   * Logs out the current user and clears session data
   *
   * Removes JWT token and user ID from secure storage, effectively
   * ending the user's authenticated session.
   */
  static Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'userId');

    await OneSignal.logout();
  }

  /*
   * Changes the authenticated user's password
   *
   * Sends password change request to /auth/change-password endpoint.
   * Requires current password verification for security.
   *
   * @param currentPassword User's current password for verification
   * @param newPassword New password to set
   * @throws Exception if password change fails or user is not authenticated
   */
  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (mockChangePassword != null) {
      return mockChangePassword!(currentPassword, newPassword);
    }

    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.put(
      ApiClient.uri('auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Failed to change password',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }
}
