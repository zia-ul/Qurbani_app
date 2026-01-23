import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminApplicationService {
  // static const _baseUrl = 'http://192.168.1.4:3000/api';
  static const _baseUrl = 'http://192.168.1.4:3000/api';
  static const _storage = FlutterSecureStorage();

  static Future<void> apply({
    required String organizationName,
    required String phone,
    required String experience,
    required String address,
    required File govtId,
    required File businessProof,
    required File bankProof,
    required File farmPhoto,
  }) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Unauthorized');

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/apply'),
    );

    req.headers['Authorization'] = 'Bearer $token';

    req.fields.addAll({
      'organizationName': organizationName,
      'phone': phone,
      'experience': experience,
      'address': address,
    });

    req.files.add(await http.MultipartFile.fromPath('govtId', govtId.path));
    req.files.add(
      await http.MultipartFile.fromPath('businessProof', businessProof.path),
    );
    req.files.add(
      await http.MultipartFile.fromPath('bankProof', bankProof.path),
    );
    req.files.add(
      await http.MultipartFile.fromPath('farmPhoto', farmPhoto.path),
    );

    final res = await req.send();

    if (res.statusCode != 201) {
      throw Exception('Failed to submit application');
    }
  }
}
