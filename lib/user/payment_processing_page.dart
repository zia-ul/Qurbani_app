import 'package:flutter/material.dart';
import 'payment_success_page.dart';

class PaymentProcessingPage extends StatelessWidget {
  final Map<String, dynamic> orderData; // FULL ORDER DATA

  const PaymentProcessingPage({
    super.key,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final String paymentMethod = orderData['paymentMethod'] ?? 'online';
    final double amount =
        double.tryParse(orderData['totalAmount'].toString()) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          paymentMethod == 'online'
              ? "Online Payment"
              : "Cash on Delivery",
        ),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // ⏳ Simulate payment processing
            await Future.delayed(const Duration(seconds: 2));

            // ✅ Navigate to success page with FULL order data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccessPage(
                  orderData: orderData, // 👈 FULL DATA
                ),
              ),
            );
          },
          child: Text(
            paymentMethod == 'online'
                ? "Pay ₹$amount"
                : "Confirm Cash Order",
          ),
        ),
      ),
    );
  }
}
