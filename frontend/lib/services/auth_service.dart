import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/**
 * AuthService Class
 *
 * Singleton service class that provides authentication functionality.
 * Handles communication with authentication endpoints and manages user sessions.
 */
class AuthService {
  // Secure storage instance for JWT tokens and user data
  static const _storage = FlutterSecureStorage();

  // Base URL for API endpoints (development server)
  static final String? _baseUrl =  dotenv.env['BASE_URL'];

  static Future<void> Function(String current, String next)?
      mockChangePassword;

  // GET CURRENT USER (with token)
  static Future<UserModel?> getCurrentUser() async {
    // print("AuthService: getCurrentUser called");

    final token = await _storage.read(key: 'token');
    // print("AuthService: token = $token");

    if (token == null) {
      // print("AuthService: No token found");
      return null;
    }

    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    // print("AuthService: /auth/me status = ${res.statusCode}");
    // print("AuthService: /auth/me body = ${res.body}");

    if (res.statusCode != 200) {
      // print("AuthService: Invalid token, deleting it");
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'userId');
      return null;
    }

    final decoded = jsonDecode(res.body);

    if (decoded['user'] == null) {
      // print("AuthService: user key missing in response");
      return null;
    }

    return UserModel.fromJson(decoded['user']);
  }

  /**
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
    // print(data);

    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    // print(res.body);

    if (res.statusCode != 201) {
      final msg = jsonDecode(res.body)['message'] ?? 'Registration failed';
      throw Exception(msg);
    }
  }

  /**
   * Authenticates user credentials and establishes session
   *
   * Sends login request to /auth/login endpoint with email/password.
   * On success, securely stores JWT token and user ID, then returns user data.
   * Used by login screen to authenticate users and start sessions.
   *
   * @param data Map containing 'email' and 'password' keys
   * @return UserModel containing authenticated user information
   * @throws Exception if login fails with server error message
   */
  static Future<UserModel> login(Map<String, dynamic> data) async {
    // print(data);
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (res.statusCode != 200) {
      final msg = jsonDecode(res.body)['message'] ?? 'Login failed';
      throw Exception(msg);
    }

    final body = jsonDecode(res.body);

    // Save JWT token securely
    final token = body['token'];
    final user = body['user'];
    if (token != null) {
      await _storage.write(key: 'token', value: token);
      await _storage.write(key: 'userId', value: user['id']);
    }

    // Return user data
    return UserModel.fromJson(user);
  }

  /**
   * Logs out the current user and clears session data
   *
   * Removes JWT token and user ID from secure storage, effectively
   * ending the user's authenticated session.
   */
  static Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'userId');
  }

  /**
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
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/auth/change-password'),
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
      final msg =
          jsonDecode(res.body)['message'] ?? 'Failed to change password';
      throw Exception(msg);
    }
  }
}
