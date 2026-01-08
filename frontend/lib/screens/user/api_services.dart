import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiServices {
  Future<Map<String, dynamic>> razorPayApi(
      double totalAmount, String orderId) async {
    final key = dotenv.get('RAZOR_KEY', fallback: '');
    final secret = dotenv.get('RAZOR_SECRET', fallback: '');
    if (key.isEmpty || secret.isEmpty) {
      throw Exception("Razorpay key/secret not found in .env");
    }

    // Razorpay requires amount in paise
    final int amountPaise = (totalAmount * 100).toInt();
    if (amountPaise < 100) {
      throw Exception("Amount must be at least 1 INR (100 paise)");
    }

    final uri = Uri.parse("https://api.razorpay.com/v1/orders");

    final body = jsonEncode({
      "amount": amountPaise,
      "currency": "INR",
      "receipt": "receipt_$orderId",
      "payment_capture": 1
    });

    final credentials = base64Encode(utf8.encode('$key:$secret'));

    print("Razorpay Request Body: $body");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Basic $credentials",
      },
      body: body,
    );

    print("Razorpay Response Status: ${response.statusCode}");
    print("Razorpay Response Body: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {"status": "success", "body": jsonDecode(response.body)};
    } else {
      return {"status": "error", "body": jsonDecode(response.body)};
    }
  }
}
