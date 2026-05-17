import 'package:Qurbani/screens/user/marketplace.dart';
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
  bool _isStartingPayment = false;
  Map<String, dynamic>? _paymentOrder;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _startPayment() async {
    if (_isStartingPayment) return;

    setState(() => _isStartingPayment = true);

    try {
      final paymentOrder = await OrderService.createRazorpayOrder(
        widget.orderId,
      );

      _paymentOrder = paymentOrder;

      final options = {
        'key': paymentOrder['key_id'],
        'amount': paymentOrder['amount'],
        'currency': paymentOrder['currency'] ?? 'INR',
        'name': 'Qurbani',
        'description': 'Order #${widget.orderId}',
        'order_id': paymentOrder['razorpay_order_id'],
        'prefill': {'contact': '', 'email': ''},
        'notes': {'orderId': widget.orderId},
      };
      _razorpay.open(options);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Unable to start payment: $e",
        backgroundColor: AppTheme.warningRed,
        textColor: AppTheme.bgGradientEnd,
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingPayment = false);
      }
    }
  }

  void _handleSuccess(PaymentSuccessResponse res) async {
    try {
      final razorpayOrderId =
          res.orderId ?? _paymentOrder?['razorpay_order_id']?.toString();
      final razorpayPaymentId = res.paymentId;
      final razorpaySignature = res.signature;

      if (razorpayOrderId == null ||
          razorpayPaymentId == null ||
          razorpaySignature == null) {
        throw Exception("Payment response is missing verification details");
      }

      await OrderService.verifyRazorpayPayment(
        orderId: widget.orderId,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );
      Fluttertoast.showToast(
        msg: "Payment verified successfully!",
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
        msg: "Payment verification failed: $e",
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
          onPressed: _isStartingPayment ? null : _startPayment,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: Text(
            _isStartingPayment ? "Starting..." : "Pay Now",
            style: const TextStyle(fontSize: 18),
          ),
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
