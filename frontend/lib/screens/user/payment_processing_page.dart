import 'package:Qurbani/screens/user/marketplace.dart';
import 'package:Qurbani/screens/user/user_home_screen.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PaymentProcessingPage extends StatefulWidget {
  final String orderId;
  final double totalAmount; // In INR

  const PaymentProcessingPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_RvnWCRmWH17BYb', // Replace with your key
      'amount': (widget.totalAmount * 100).round(), // Paise
      'currency': 'INR',
      'name': 'Qurbani',
      'description': 'Order Payment',
      'prefill': {
        'contact': '', // Add user contact if available
        'email': '', // Add user email if available
      },
    };
    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse res) async {
    try {
      await OrderService.updatePaymentSuccess(widget.orderId, res.paymentId!);
      Fluttertoast.showToast(
        msg: "Payment Successful!",
        backgroundColor: Colors.green,
        textColor: AppTheme.bgGradientEnd,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AdminDirectoryPage()),
        (route) => false, // 🔥 clears entire back stack
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Payment recorded, but error updating: $e",
        backgroundColor: Colors.orange,
        textColor: AppTheme.bgGradientEnd,
      );
    }
  }

  void _handleError(PaymentFailureResponse res) {
    Fluttertoast.showToast(
      msg: "Payment Failed: ${res.message}",
      backgroundColor: AppTheme.warningRed,
      textColor: AppTheme.bgGradientEnd,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse res) {
    Fluttertoast.showToast(
      msg: "Wallet Selected: ${res.walletName}",
      backgroundColor: Colors.blue,
      textColor: AppTheme.bgGradientEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Checkout"),
        backgroundColor: const Color(0xff3D6B4E),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _startPayment,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text("Pay Now", style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}
