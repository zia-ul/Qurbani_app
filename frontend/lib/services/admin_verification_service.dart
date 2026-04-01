import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AdminVerificationService {
  static const _storage = FlutterSecureStorage();

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

  static Future<void> submitVerification(Map<String, dynamic> data) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.post(
      ApiClient.uri('admin/verification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode != 201) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage:
            'Unable to submit your verification requirements right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }
  }

  static Future<String?> getVerificationStatus() async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw const ApiException('Not authenticated');

    final res = await ApiClient.get(
      ApiClient.uri('verification/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final msg = ApiClient.errorMessage(
        res,
        fallbackMessage: 'Unable to check verification status right now.',
      );
      throw ApiException(msg, statusCode: res.statusCode);
    }

    final data = ApiClient.decodeMap(
      res,
      fallbackMessage: 'Unable to check verification status right now.',
    );
    return data['status'];
  }
}
