import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  // language state variable
  static String _currentLanguage = 'en'; // default

  // getter
  static String get currentLanguage => _currentLanguage;

  // setter
  static set currentLanguage(String lang) {
    _currentLanguage = lang;
  }

  // Translator function
  static Future<String> tr(String input) async {
    try {
      final result = await _translator.translate(input, to: _currentLanguage);
      return result.text;
    } catch (e) {
      return input; // fallback if translation fails
    }
  }
}
