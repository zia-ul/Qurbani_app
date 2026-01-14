import 'package:flutter/material.dart';
import 'package:qurbani/services/currency_service.dart';

class CurrencyNotifier extends ChangeNotifier {
  String _currency = 'USD';
  final CurrencyService _currencyService = currencyService;

  CurrencyNotifier() {
    _currencyService.initialize();
  }

  String get currency => _currency;

  void setCurrency(String value) {
    if (_currency == value) return;
    _currency = value;
    notifyListeners();
  }

  double convert(double amount) {
    return _currencyService.convert(amount, _currency);
  }

  Map<String, double>? get rates => _currencyService.rates;
}
