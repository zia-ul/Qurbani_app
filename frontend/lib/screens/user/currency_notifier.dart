// import 'package:flutter/material.dart';
// import 'package:Qurbani/exchange_rates.dart';

// /// Currency change notifier to automatically update all currency-dependent widgets
// class CurrencyNotifier extends ChangeNotifier {
//   String _currentCurrency = 'USD';
//   double _currentRate = 1.0;

//   String get currentCurrency => _currentCurrency;
//   double get currentRate => _currentRate;

//   /// Initialize with current user currency
//   Future<void> initialize() async {
//     await UserCurrency.init();
//     _currentCurrency = UserCurrency.currency;
//     _currentRate = UserCurrency.rate;
//     notifyListeners();
//   }

//   /// Update currency and notify all listeners
//   Future<void> updateCurrency(String newCurrency) async {
//     // Update in Firestore and local storage (handled by settings page)
//     // Just update our internal state and notify
//     _currentCurrency = newCurrency;

//     // Re-initialize UserCurrency to get new rate
//     UserCurrency.reset();
//     await UserCurrency.init();

//     _currentRate = UserCurrency.rate;
//     notifyListeners();
//   }

//   /// Get converted amount using current rate
//   double convert(double amountUSD) {
//     return amountUSD * _currentRate;
//   }

//   /// Get currency symbol
//   String getCurrencySymbol() {
//     switch (_currentCurrency) {
//       case "INR":
//         return "₹";
//       case "USD":
//         return "\$";
//       case "AED":
//         return "د.إ ";
//       case "PKR":
//         return "Rs ";
//       default:
//         return "$_currentCurrency ";
//     }
//   }
// }

// /// Global currency notifier instance
// final currencyNotifier = CurrencyNotifier();
