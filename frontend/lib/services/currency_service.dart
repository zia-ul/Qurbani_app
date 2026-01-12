import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _apiKey = '77cbc2e641a244e9bde5a7c03a01367a'; // OpenExchangeRates app ID
  static const String _baseUrl = 'https://openexchangerates.org/api/latest.json?app_id=$_apiKey';
  static const Duration _updateInterval = Duration(minutes: 45); // ~32 requests/day

  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  Map<String, double>? _rates;
  String _baseCurrency = 'USD'; // Default base
  Timer? _updateTimer;
  bool _isInitialized = false;

  // Initialize: Load cached rates and start auto-update
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadCachedRates();
    await _fetchRates(); // Initial fetch
    _startAutoUpdate();
    _isInitialized = true;
  }

  // Fetch rates from API
  Future<void> _fetchRates() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _rates = Map<String, double>.from(data['rates']);
        _baseCurrency = data['base'] ?? 'USD';
        await _cacheRates(); // Save to local storage
      } else {
        print(response.body);
        throw Exception('Failed to fetch rates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching rates: $e');
      // Use cached rates if available
    }
  }

  // Load cached rates from shared preferences
  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRates = prefs.getString('exchange_rates');
    if (cachedRates != null) {
      final data = jsonDecode(cachedRates);
      _rates = Map<String, double>.from(data['rates']);
      _baseCurrency = data['base'] ?? 'USD';
    }
  }

  // Cache rates to shared preferences
  Future<void> _cacheRates() async {
    if (_rates != null) {
      final prefs = await SharedPreferences.getInstance();
      final data = {'rates': _rates, 'base': _baseCurrency};
      await prefs.setString('exchange_rates', jsonEncode(data));
    }
  }

  // Start auto-update timer
  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(_updateInterval, (_) async {
      await _fetchRates();
      // Notify listeners
      // currencyNotifier.notifyListeners();
    });
  }

  // Convert amount from base currency to target currency
  double convert(double amount, String targetCurrency) {
    if (_rates == null || !_rates!.containsKey(targetCurrency)) {
      return amount; // Fallback: no conversion
    }
    final baseRate = _rates![_baseCurrency] ?? 1.0;
    final targetRate = _rates![targetCurrency]!;
    return amount * (targetRate / baseRate);
  }

  // Get current rates (for debugging or UI)
  Map<String, double>? get rates => _rates;
  String get baseCurrency => _baseCurrency;

  // Dispose (call in app lifecycle if needed)
  void dispose() {
    _updateTimer?.cancel();
  }
}

// Global instance
final currencyService = CurrencyService();