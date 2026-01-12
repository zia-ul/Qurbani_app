import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  // GET CURRENT USER (with token)
  static Future<UserModel?> getCurrentUser() async {
  print("AuthService: getCurrentUser called");

  final token = await _storage.read(key: 'token');
  print("AuthService: token = $token");

  

  if (token == null) {
    print("AuthService: No token found");
    return null;
  }

  final res = await http.get(
    Uri.parse('$_baseUrl/auth/me'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  print("AuthService: /auth/me status = ${res.statusCode}");
  print("AuthService: /auth/me body = ${res.body}");

  if (res.statusCode != 200) {
    print("AuthService: Invalid token, deleting it");
    await _storage.delete(key: 'token');
    return null;
  }

  final decoded = jsonDecode(res.body);

  if (decoded['user'] == null) {
    print("AuthService: user key missing in response");
    return null;
  }

  return UserModel.fromJson(decoded['user']);
}


  // REGISTER
  static Future<void> register(Map<String, dynamic> data) async {
    print(data);
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    print(res.body);

    if (res.statusCode != 201) {
      final msg = jsonDecode(res.body)['message'] ?? 'Registration failed';
      throw Exception(msg);
    }
  }

  // LOGIN
  static Future<UserModel> login(Map<String, dynamic> data) async {
    print(data);
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
    if (token != null) {
      await _storage.write(key: 'token', value: token);
    }

    // Return user data
    return UserModel.fromJson(body['user']);
  }

  // LOGOUT
  static Future<void> logout() async {
    await _storage.delete(key: 'token');
  }
}
