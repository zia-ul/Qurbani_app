import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CurrencyService {
  static const Duration _updateInterval = Duration(minutes: 45);
  static final String? _baseUrl = dotenv.env['BASE_URL'];
  static bool disableAutoUpdateForTests = false;
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  /// Internal state
  Map<String, double> _rates = {};
  String _baseCurrency = 'USD';

  Timer? _updateTimer;
  bool _isInitialized = false;
  bool _isFetching = false;
  final Completer<void> _initCompleter = Completer<void>();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // PUBLIC GETTERS
  // ---------------------------------------------------------------------------

  /// All exchange rates
  Map<String, double> get rates => _rates;

  /// Base currency (admin currency)
  String get baseCurrency => _baseCurrency;

  /// Whether service is ready
  bool get isInitialized => _isInitialized;

  /// Supported currency codes
  List<String> get supportedCurrencies => _rates.keys.toList()..sort();

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  /**
   * Initializes the currency service with current exchange rates
   *
   * Performs initial setup including fetching current rates from backend,
   * starting auto-update timer, and marking service as ready. This method
   * should be called once during app initialization.
   *
   * @throws Exception if initial rate fetch fails
   */
  Future<void> initialize() async {
    if (_isInitialized) return _initCompleter.future;

    try {
      await _fetchRates();
      _startAutoUpdate();
      _isInitialized = true;
      _initCompleter.complete();
      debugPrint("CurrencyService initialized");
    } catch (e) {
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Fetch user currency from backend
  // Future<String> fetchUserCurrency(String userId) async {
  //   final url = Uri.parse('$_baseUrl/users/$userId/currency');

  //   final res = await http.get(url);

  //   if (res.statusCode != 200) {
  //     throw Exception('Failed to fetch user currency');
  //   }

  //   final data = jsonDecode(res.body);
  //   final currency = data['currency'] ?? 'USD';
  //   print("testing user currency ....$currency");

  //   if (!supportedCurrencies.contains(currency)) {
  //     return baseCurrency;
  //   }

  //   return currency;
  // }

  // ---------------------------------------------------------------------------
  // FETCH
  // ---------------------------------------------------------------------------

  Future<void> _fetchRates() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final res = await http.get(Uri.parse('$_baseUrl/users/currencies'));
      if (res.statusCode != 200) {
        debugPrint("Currency fetch failed: ${res.body}");
        return;
      }

      final data = jsonDecode(res.body);

      _baseCurrency = data['base'] ?? 'USD';

      _rates = Map<String, double>.from(
        (data['rates'] as Map).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      );

      debugPrint(
        "Currencies loaded ($_baseCurrency → ${_rates.length}): "
        "${supportedCurrencies.take(5)}",
      );
    } catch (e) {
      debugPrint("Currency fetch error: $e");
    } finally {
      _isFetching = false;
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERSION
  // ---------------------------------------------------------------------------

  /// Convert from BASE (USD/admin) → target currency
  double convert(double amount, String targetCurrency) {
    if (_rates.isEmpty) return amount;
    if (!_rates.containsKey(targetCurrency)) return amount;
    if (_baseCurrency == targetCurrency) return amount;

    return amount * _rates[targetCurrency]!;
  }

  // ---------------------------------------------------------------------------
  // USER CURRENCY UPDATE
  // ---------------------------------------------------------------------------

  /**
   * Updates the authenticated user's preferred currency setting
   *
   * Saves the user's currency preference to their profile. This affects
   * how prices and amounts are displayed throughout the app for this user.
   * Requires authentication and updates the backend user profile.
   *
   * @param currency Currency code to set as user's preference (e.g., 'USD', 'EUR')
   * @throws Exception if update fails or user is not authenticated
   */
  static Future<void> setUserCurrency(String currency) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('$_baseUrl/users/profile/currency'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'currency': currency}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update currency');
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO UPDATE
  // ---------------------------------------------------------------------------

  void _startAutoUpdate() {
    if (disableAutoUpdateForTests) return;

    _updateTimer = Timer.periodic(
      const Duration(minutes: 45),
      (_) => _fetchRates(),
    );
  }

  void dispose() {
    _updateTimer?.cancel();
  }
}

/// Global singleton
final currencyService = CurrencyService();
