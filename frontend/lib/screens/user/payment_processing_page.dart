import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentProcessingPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const PaymentProcessingPage({super.key, required this.orderData});

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  late Razorpay _razorpay;
  int finalAmountPaise = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _prepareAmount();
  }

  /// 💰 Directly use INR amount
  void _prepareAmount() {
    double total = (widget.orderData['totalAmount'] ?? 0).toDouble();
    finalAmountPaise = (total * 100).round(); // INR → Paise
    widget.orderData['amountINR'] = total;

    setState(() => loading = false);
  }

  /// 🚀 Open Razorpay
  void _openGateway() {
    var options = {
      'key': 'rzp_test_RvnWCRmWH17BYb',
      'amount': finalAmountPaise,
      'currency': 'INR',
      'name': 'Qurbani',
      'description': "Order Payment",
      'prefill': {
        'contact': widget.orderData['phone'] ?? '',
        'email': widget.orderData['email'] ?? '',
      },
    };
    _razorpay.open(options);
  }

  /// 🎉 Success
  void _handleSuccess(PaymentSuccessResponse res) async {
    await FirebaseFirestore.instance
        .collection("orders")
        .doc(widget.orderData['orderId'])
        .update({
          "paymentStatus": "Paid",
          "paymentId": res.paymentId,
          "paymentDate": DateTime.now(),
          "method": "Razorpay",
        });

    Navigator.pop(context); // Back to previous page
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("🎉 Payment Successful")));
  }

  /// ❌ Failure
  void _handleError(PaymentFailureResponse res) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("❌ Payment Failed: ${res.message}")));
  }

  /// 👛 Wallet used
  void _handleExternalWallet(ExternalWalletResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Wallet Selected: ${res.walletName}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Checkout")),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _openGateway,
                child: const Text("Pay Now"),
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
