import 'package:flutter/material.dart';
import 'package:Qurbani/services/currency_service.dart';

class CurrencyNotifier extends ChangeNotifier {
  String _currency = 'USD';
  bool _isLoading = true;
  bool _hasError = false;

  final CurrencyService _currencyService;

  CurrencyNotifier({CurrencyService? service})
      : _currencyService = service ?? currencyService {
    _init();
  }

  Future<void> _init() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _currencyService.initialize();
      debugPrint(
        "Rates loaded: ${_currencyService.supportedCurrencies}",
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CurrencyService init failed: $e');
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔹 Call this AFTER profile loads
  void setInitialCurrency(String currency) {
    _currency = currency;
    notifyListeners();
  }

  String get currency => _currency;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  bool get isReady =>
      !_isLoading && !_hasError && _currencyService.rates != null;

  /// ✅ Supported currencies for dropdown
  List<String> get supportedCurrencies =>
      _currencyService.supportedCurrencies;

  /// USD → selected currency
  double convert(double amount) {
    if (!isReady) return amount;
    return _currencyService.convert(amount, _currency);
  }

  /// Change currency from UI
  void setCurrency(String value) {
    if (_currency == value) return;
    _currency = value;
    notifyListeners();
  }

  Map<String, double>? get rates => _currencyService.rates;
}
