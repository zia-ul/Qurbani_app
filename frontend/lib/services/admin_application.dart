import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminApplicationService {
  static final String? _baseUrl =  dotenv.env['BASE_URL'];
  static const _storage = FlutterSecureStorage();

  /**
   * Submits an admin application with required documentation
   *
   * Handles the complete admin application process including organization details,
   * contact information, and required document uploads (government ID, business proof,
   * bank proof, and farm photos). Used for users applying to become admins in the system.
   *
   * @param organizationName Name of the organization applying for admin status
   * @param phone Contact phone number for the organization
   * @param experience Years or description of relevant experience
   * @param address Physical address of the organization/farm
   * @param govtId Government-issued ID document file
   * @param businessProof Business registration or proof document file
   * @param bankProof Bank account verification document file
   * @param farmPhoto Photo of the farm/operation
   * @throws Exception if application submission fails or user is not authenticated
   */
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
