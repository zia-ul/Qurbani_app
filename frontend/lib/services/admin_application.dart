import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/services/upload_service.dart';

class AdminApplicationService {
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

    final uploaded = await UploadService.uploadFiles([
      govtId.path,
      businessProof.path,
      bankProof.path,
      farmPhoto.path,
    ], context: 'admin_verification');

    if (uploaded.length != 4) {
      throw const ApiException('Failed to upload all application documents');
    }

    final res = await ApiClient.post(
      ApiClient.uri('admin/verification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'organizationName': organizationName,
        'organization_name': organizationName,
        'phone': phone,
        'experience': experience,
        'address': address,
        'govt_id_url': uploaded[0].url,
        'business_proof_url': uploaded[1].url,
        'bank_proof_url': uploaded[2].url,
        'farm_photo_url': uploaded[3].url,
      }),
    );

    if (res.statusCode != 201) {
      throw ApiException(
        ApiClient.errorMessage(
          res,
          fallbackMessage: 'Failed to submit application',
        ),
        statusCode: res.statusCode,
      );
    }
  }
}
