import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qurbani/screens/user/payment_success_page.dart';
import 'package:qurbani/widgets/success_error_popup.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RazorPayIntegration {
  final Razorpay _razorpay = Razorpay();
  final razorPayKey = dotenv.get("RAZOR_KEY");
  final razorPaySecret = dotenv.get("RAZOR_SECRET");

  BuildContext? context;
  Map<String, dynamic>? orderData;

  /// INITIALIZE CALLBACKS
  void init({required BuildContext ctx, required Map<String, dynamic> data}) {
    context = ctx;
    orderData = data;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// CREATE ORDER -> OPEN UI
  Future<void> startPayment() async {
    final num amount = orderData?['totalAmount'] ?? 0;
    final double amountDouble = amount.toDouble(); // convert num → double

    final orderId = await createOrder(amount: amountDouble);
    if (orderId.isEmpty) {
      _showSnack("❌ Failed to create payment order");
      return;
    }

    var options = {
      'key': razorPayKey,
      'order_id': orderId,
      'amount': (amountDouble * 100).toInt(), // INR → Paise
      'name': 'Qurbani',
      'description': 'Order Payment',
      'timeout': 300,
      'prefill': {
        'contact': orderData?['phone'] ?? '',
        'email': orderData?['email'] ?? '',
      },
    };

    _razorpay.open(options);
  }

  /// API → CREATE ORDER ON RAZORPAY
  Future<String> createOrder({required double amount}) async {
    final response = await ApiServices().razorPayApi(
      amount,
      "receipt_${DateTime.now().millisecondsSinceEpoch}",
    );
    if (response["status"] == "success") {
      return response["body"]["id"];
    }
    return "";
  }

  /// SUCCESS CALLBACK
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    await FirebaseFirestore.instance
        .collection("orders")
        .doc(orderData!['orderId'])
        .update({
          "paymentStatus": "Paid",
          "paymentId": response.paymentId,
          "paymentDate": DateTime.now(),
          "method": "Razorpay",
        });

    _showSnack("🎉 Payment Successful");
    // Navigate to PaymentSuccessPage
    if (context != null) {
      Navigator.pushReplacement(
        context!,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(orderData: orderData!),
        ),
      );
    }
  }

  /// FAILURE
  void _handlePaymentError(PaymentFailureResponse response) {
    _showSnack("❌ Payment Failed: ${response.message}");
  }

  /// WALLET
  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnack("👛 Wallet Selected: ${response.walletName}");
  }

  /// CLEAR
  void dispose() {
    _razorpay.clear();
  }

  void _showSnack(String msg) {
    if (context != null) {
      ToastUtils.showError(msg);

    }
  }
}
