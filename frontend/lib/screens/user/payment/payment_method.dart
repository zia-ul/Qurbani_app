import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/user/api_services.dart';
import 'package:qurbani/screens/user/cod_payment.dart';
import 'payment_processing2.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData; // FULL order data from ProceedPage

  const PaymentMethodPage({super.key, required this.orderData});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> allowedMethods = [];
  String? selectedMethod;
  bool loadingMethods = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prepareCartItemsWithMethods();
  }

  /// Ensure each cart item includes paymentMethods
  Future<void> _prepareCartItemsWithMethods() async {
    final cartItems = widget.orderData['cartItems'] as List<dynamic>;
    List<Map<String, dynamic>> updatedCartItems = [];

    for (var item in cartItems) {
      final doc = await _firestore
          .collection('animals')
          .doc(item['animalId'])
          .get();
      final data = doc.data() ?? {};
      updatedCartItems.add({
        ...item,
        'paymentMethods': data['paymentMethods'] ?? [],
      });
    }

    // Update orderData cartItems with paymentMethods
    widget.orderData['cartItems'] = updatedCartItems;

    _extractPaymentMethods();
  }

  void _extractPaymentMethods() {
    // Collect unique allowed payment methods
    final cartItems = widget.orderData['cartItems'] as List<dynamic>;
    for (var item in cartItems) {
      final methods = item['paymentMethods'];
      if (methods != null && methods is List) {
        for (var m in methods) {
          if (!allowedMethods.contains(m)) allowedMethods.add(m);
        }
      }
    }

    // Default selection
    if (allowedMethods.isNotEmpty) selectedMethod = allowedMethods.first;

    setState(() => loadingMethods = false);
  }

  Future<void> _proceedPayment() async {
    if (isSubmitting || selectedMethod == null) return;
    setState(() => isSubmitting = true);

    try {
      final orderData = Map<String, dynamic>.from(widget.orderData);
      orderData['paymentMethod'] = selectedMethod;

      // Create unique orderId
      final orderRef = _firestore.collection('orders').doc();
      orderData['orderId'] = orderRef.id;
      print("Firestore Order ID: ${orderData['orderId']}");

      // Save basic order data
      await orderRef.set(orderData);

      if (!mounted) return;

      if (selectedMethod!.toLowerCase() == 'cod') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CashOnDeliveryPage(orderData: orderData),
          ),
        );
      } else {
        // Debug: check totalAmount
        final totalAmount = orderData['totalAmount'];
        print("Total Amount: $totalAmount");

        if (totalAmount == null || totalAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Invalid total amount")),
          );
          setState(() => isSubmitting = false);
          return;
        }

        Map<String, dynamic> orderId;
        try {
          orderId = await ApiServices().razorPayApi(
            totalAmount,
            orderData['orderId'],
          );
          print("Razorpay API Response: $orderId");
        } catch (e) {
          print("Error creating Razorpay order: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Unable to start payment — Try again"),
            ),
          );
          setState(() => isSubmitting = false);
          return;
        }

        if (orderId["status"] == "success" && orderId["body"]?["id"] != null) {
          orderData['razorpayOrderId'] = orderId["body"]["id"];
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentProcessingPage(orderData: orderData),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Unable to start payment — Try again"),
            ),
          );
          setState(() => isSubmitting = false);
        }
      }
    } catch (e) {
      print("Error in _proceedPayment: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to proceed: $e')));
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Payment Method"),
        backgroundColor: Color(0xff537D4F),
      ),
      body: loadingMethods
          ? const Center(child: CircularProgressIndicator())
          : allowedMethods.isEmpty
          ? const Center(
              child: Text(
                "⚠️ No payment methods available for selected animals.",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Multiple methods → show radio buttons
                  if (allowedMethods.length > 1)
                    ...allowedMethods.map(
                      (method) => RadioListTile<String>(
                        value: method,
                        groupValue: selectedMethod,
                        onChanged: (v) => setState(() => selectedMethod = v),
                        title: Text(
                          method.toUpperCase() == 'COD'
                              ? "Cash on Delivery"
                              : method.toUpperCase(),
                        ),
                      ),
                    ),
                  // Single method → show as selected & disabled
                  if (allowedMethods.length == 1)
                    ListTile(
                      title: Text(
                        allowedMethods.first.toUpperCase() == 'COD'
                            ? "Cash on Delivery"
                            : allowedMethods.first.toUpperCase(),
                      ),
                      leading: const Icon(
                        Icons.check,
                        color: Color(0xff537D4F),
                      ),
                    ),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _proceedPayment,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Continue"),
                  ),
                ],
              ),
            ),
    );
  }
}
