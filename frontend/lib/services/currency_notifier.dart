import 'package:flutter/material.dart';
import 'package:qurbani/services/currency_service.dart'; 

class CurrencyNotifier extends ChangeNotifier {
  String _userCurrency = 'USD'; // Default; set from user profile

  CurrencyNotifier() {
    currencyService.initialize(); // Initialize service on creation
  }

  String get userCurrency => _userCurrency;
  set userCurrency(String currency) {
    _userCurrency = currency;
    notifyListeners();
  }

  // Conversion method (centralized)
  double convert(double amount) {
    return currencyService.convert(amount, _userCurrency);
  }

  // Access rates if needed
  Map<String, double>? get rates => currencyService.rates;
}

// Global notifier (ensure it's initialized in main.dart or app root)
final currencyNotifier = CurrencyNotifier();