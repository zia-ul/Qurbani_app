import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhoneEmailConfig {
  PhoneEmailConfig._();

  static const String _placeholderClientId = 'YOUR_CLIENT_ID';

  static String get clientId =>
      (dotenv.env['PHONE_EMAIL_CLIENT_ID'] ?? '').trim();

  static bool get isConfigured =>
      clientId.isNotEmpty && clientId != _placeholderClientId;

  static String get missingClientIdMessage =>
      'Phone.Email is not configured yet. Add PHONE_EMAIL_CLIENT_ID to assets/.env.';
}
