import 'package:flutter/material.dart';
import 'razorpay_integration.dart'; // <- your current file

class PaymentProcessingPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentProcessingPage({super.key, required this.orderData});

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  late RazorPayIntegration _razorpayHandler;

  @override
  void initState() {
    super.initState();
    _razorpayHandler = RazorPayIntegration();
    _razorpayHandler.init(ctx: context, data: widget.orderData);
  }

  @override
  void dispose() {
    _razorpayHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Checkout")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _razorpayHandler.startPayment();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text(
            "Pay Now",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
