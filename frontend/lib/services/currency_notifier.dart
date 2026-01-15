import 'package:flutter/material.dart';
import 'package:qurbani/services/currency_service.dart';

class CurrencyNotifier extends ChangeNotifier {
  String _currency = 'USD';

  final CurrencyService _currencyService;

  CurrencyNotifier({CurrencyService? service})
      : _currencyService = service ?? currencyService {
    _init();
  }

  /// Initialize currency rates safely
  Future<void> _init() async {
    try {
      await _currencyService.initialize();
      notifyListeners(); // ensure UI updates after rates load
    } catch (e) {
      debugPrint('CurrencyService init failed: $e');
    }
  }

  /// Current currency
  String get currency => _currency;

  /// Update currency
  void setCurrency(String value) {
    if (_currency == value) return;
    _currency = value;
    notifyListeners();
  }

  /// Convert amount from USD to selected currency
  double convert(double amount) {
    if (_currencyService.rates == null) return amount;
    return _currencyService.convert(amount, _currency);
  }

  /// All exchange rates
  Map<String, double>? get rates => _currencyService.rates;
}
