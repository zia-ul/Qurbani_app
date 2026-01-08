// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;

// class CurrencyService {
//   static const String apiKey = "4bffc0537ff94196414d669acda56614";

//   // Cache for exchange rates to avoid redundant API calls
//   static final Map<String, double> _rateCache = {};
//   static final Map<String, DateTime> _cacheTime = {};
//   static const Duration cacheDuration = Duration(minutes: 30);

//   /// Convert from USD to target currency using your API key
//   static Future<double> convert(double amount, String targetCurrency) async {
//     if (targetCurrency == "USD" || targetCurrency.isEmpty) {
//       return amount;
//     }

//     // Normalize currency code
//     final normalizedCurrency = _normalizeCurrencyCode(targetCurrency);

//     // Check cache first
//     final cacheKey = "USD_to_$normalizedCurrency";
//     if (_isCacheValid(cacheKey)) {
//       return amount * _rateCache[cacheKey]!;
//     }

//     try {
//       final url = Uri.parse(
//         'http://api.exchangerate.host/convert?access_key=$apiKey&from=USD&to=$normalizedCurrency&amount=$amount',
//       );

//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['result'] != null) {
//           final rate = (data['result'] as num).toDouble() / amount;
//           _updateCache(cacheKey, rate);
//           return data['result'] as double;
//         } else {
//           throw Exception("Invalid API response: missing 'result' field");
//         }
//       } else {
//         throw Exception(
//           "Failed to fetch exchange rate: HTTP ${response.statusCode}",
//         );
//       }
//     } catch (e) {
//       print("Currency conversion error: $e");
//       // Return original amount as fallback
//       return amount;
//     }
//   }

//   /// Get exchange rate from USD to target currency
//   static Future<double> getRate(String targetCurrency) async {
//     if (targetCurrency == "USD" || targetCurrency.isEmpty) {
//       return 1.0;
//     }

//     final normalizedCurrency = _normalizeCurrencyCode(targetCurrency);
//     final cacheKey = "USD_to_$normalizedCurrency";

//     if (_isCacheValid(cacheKey)) {
//       return _rateCache[cacheKey]!;
//     }

//     try {
//       final url = Uri.parse(
//         'http://api.exchangerate.host/convert?access_key=$apiKey&from=USD&to=$normalizedCurrency&amount=1',
//       );

//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['result'] != null) {
//           final rate = (data['result'] as num).toDouble();
//           _updateCache(cacheKey, rate);
//           return rate;
//         } else {
//           throw Exception("Invalid API response: missing 'result' field");
//         }
//       } else {
//         throw Exception(
//           "Failed to fetch exchange rate: HTTP ${response.statusCode}",
//         );
//       }
//     } catch (e) {
//       print("Currency rate fetch error: $e");
//       return 1.0; // Return USD rate as fallback
//     }
//   }

//   /// Validate and normalize currency code
//   static String _normalizeCurrencyCode(String currency) {
//     return currency.toUpperCase().trim();
//   }

//   /// Check if cached rate is still valid
//   static bool _isCacheValid(String cacheKey) {
//     if (!_rateCache.containsKey(cacheKey)) return false;

//     final lastUpdated = _cacheTime[cacheKey];
//     if (lastUpdated == null) return false;

//     return DateTime.now().difference(lastUpdated) < cacheDuration;
//   }

//   /// Update cache with new rate
//   static void _updateCache(String cacheKey, double rate) {
//     _rateCache[cacheKey] = rate;
//     _cacheTime[cacheKey] = DateTime.now();
//   }

//   /// Clear all cached rates (useful for testing or when user changes currency)
//   static void clearCache() {
//     _rateCache.clear();
//     _cacheTime.clear();
//   }
// }

// class UserCurrency {
//   static String currency = 'USD';
//   static double rate = 1.0;
//   static bool _isInitialized = false;

//   /// Initialize user currency from Firestore
//   static Future<void> init() async {
//     if (_isInitialized) return;

//     try {
//       final userId = FirebaseAuth.instance.currentUser!.uid;
//       final doc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .get();

//       if (doc.exists) {
//         final userCurrency = doc.data()?['currency'] ?? 'USD';
//         currency = _normalizeCurrency(userCurrency);
//       } else {
//         currency = 'USD';
//       }

//       rate = await CurrencyService.getRate(currency);
//       _isInitialized = true;
//     } catch (e) {
//       print("User currency initialization error: $e");
//       currency = 'USD';
//       rate = 1.0;
//       _isInitialized = true;
//     }
//   }

//   /// Reset initialization state (useful for testing or when user changes currency)
//   static void reset() {
//     _isInitialized = false;
//     currency = 'USD';
//     rate = 1.0;
//   }

//   /// Convert USD amount to user's currency
//   static double convert(double amountUSD) {
//     return amountUSD * rate;
//   }

//   /// Convert from one currency to another
//   static Future<double> convertBetweenCurrencies(
//     double amount,
//     String fromCurrency,
//     String toCurrency,
//   ) async {
//     if (fromCurrency == toCurrency) return amount;

//     final fromRate = await CurrencyService.getRate(fromCurrency);
//     final toRate = await CurrencyService.getRate(toCurrency);

//     // Convert fromCurrency -> USD -> toCurrency
//     final amountInUSD = amount / fromRate;
//     return amountInUSD * toRate;
//   }

//   /// Normalize currency code
//   static String _normalizeCurrency(String currency) {
//     return currency.toUpperCase().trim();
//   }
// }
