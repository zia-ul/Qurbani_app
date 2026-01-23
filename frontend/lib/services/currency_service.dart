import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CurrencyService {
  static const Duration _updateInterval = Duration(minutes: 45);
  static const String _backendUrl =
      'http://192.168.1.4:3000/api/users/currencies';

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
  // ✅ PUBLIC GETTERS (THIS FIXES ALL YOUR ERRORS)
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

  // ---------------------------------------------------------------------------
  // FETCH
  // ---------------------------------------------------------------------------

  Future<void> _fetchRates() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final res = await http.get(Uri.parse(_backendUrl));
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

  static Future<void> setUserCurrency(String currency) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final res = await http.put(
      Uri.parse('http://192.168.1.4:3000/api/users/profile/currency'),
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
    _updateTimer = Timer.periodic(_updateInterval, (_) => _fetchRates());
  }

  void dispose() {
    _updateTimer?.cancel();
  }
}

/// Global singleton
final currencyService = CurrencyService();
