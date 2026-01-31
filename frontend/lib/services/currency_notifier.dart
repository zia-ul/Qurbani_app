import 'package:flutter/material.dart';
import 'package:Qurbani/services/currency_service.dart';

class CurrencyNotifier extends ChangeNotifier {
  /// User-selected currency (display only)
  String _currency = 'USD';

  /// Admin/base currency (prices come in this)
  String _baseCurrency = 'USD';

  bool _isLoading = true;
  bool _hasError = false;

  final CurrencyService _currencyService;

  CurrencyNotifier({CurrencyService? service})
    : _currencyService = service ?? currencyService {
    _init();
  }

  // ================= INIT =================

  Future<void> _init() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _currencyService.initialize();

      _baseCurrency = _currencyService.baseCurrency;

      debugPrint(
        "CurrencyNotifier ready | base=$_baseCurrency | supported=${_currencyService.supportedCurrencies}",
      );

      _isLoading = false;
      _hasError = false;
      notifyListeners();
    } catch (e) {
      debugPrint("CurrencyNotifier init failed: $e");
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  // ================= GETTERS =================

  String get currency => _currency;
  String get baseCurrency => _baseCurrency;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  bool get isReady => !_isLoading && !_hasError;

  List<String> get supportedCurrencies => _currencyService.supportedCurrencies;

  // ================= SETUP =================

  /// Call AFTER profile + animals load
  void setInitialCurrency({
    required String baseCurrency,
    required String userCurrency,
  }) {
    _baseCurrency = baseCurrency;
    _currency = userCurrency;
    notifyListeners();
  }

  void setCurrency(String val) {
    _currency = val;
    notifyListeners();
  }

  // ================= CONVERSION =================

  /// Convert from ADMIN currency → USER currency
  double convert(double amountInBaseCurrency) {
    if (!isReady) return amountInBaseCurrency;
    if (_currency == _baseCurrency) return amountInBaseCurrency;

    return _currencyService.convert(amountInBaseCurrency, _currency);
  }

  // ================= USER ACTION =================

  /// Called from dropdown / UI
  // Future<void> setCurrency(String value) async {
  //   if (_currency == value) return;

  //   _currency = value;
  //   notifyListeners();

  //   try {
  //     await CurrencyService.setUserCurrency(value);
  //   } catch (e) {
  //     debugPrint("Failed to persist user currency: $e");
  //   }
  // }
}
