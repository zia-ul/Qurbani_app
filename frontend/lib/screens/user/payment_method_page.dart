import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Qurbani/screens/user/api_services.dart';
import 'package:Qurbani/screens/user/review_order.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

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

  final Color parchmentBg = const Color(0xFFF4F7F4);

  // Map of method IDs to UI details
  final Map<String, Map<String, dynamic>> methodUI = {
    'cod': {
      'title': 'Cash on Delivery',
      'subtitle': 'Pay when your animal is delivered',
      'icon': Icons.payments_outlined,
    },
    'online': {
      'title': 'Online Payment',
      'subtitle': 'Pay securely via Credit/Debit card',
      'icon': Icons.credit_card_outlined,
    },
  };

  @override
  void initState() {
    super.initState();
    _prepareCartItemsWithMethods();
  }

  /// LOGIC: Ensure each cart item includes paymentMethods from DB
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

    widget.orderData['cartItems'] = updatedCartItems;
    _extractPaymentMethods();
  }

  /// LOGIC: Filter unique methods
  void _extractPaymentMethods() {
    final cartItems = widget.orderData['cartItems'] as List<dynamic>;
    List<String> foundMethods = [];
    for (var item in cartItems) {
      final methods = item['paymentMethods'];
      if (methods != null && methods is List) {
        for (var m in methods) {
          if (!foundMethods.contains(m.toString().toLowerCase())) {
            foundMethods.add(m.toString().toLowerCase());
          }
        }
      }
    }

    setState(() {
      allowedMethods = foundMethods;
      if (allowedMethods.isNotEmpty) selectedMethod = allowedMethods.first;
      loadingMethods = false;
    });
  }

  /// LOGIC: Process Payment & Firestore Entry
  Future<void> _proceedPayment() async {
    if (isSubmitting || selectedMethod == null) return;
    setState(() => isSubmitting = true);

    try {
      final orderData = Map<String, dynamic>.from(widget.orderData);
      orderData['paymentMethod'] = selectedMethod;

      // Create unique orderId
      final orderRef = _firestore.collection('orders').doc();
      orderData['orderId'] = orderRef.id;

      // Save basic order data to Firestore
      await orderRef.set(orderData);

      if (!mounted) return;

      if (selectedMethod == 'cod') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewOrderPage(orderData: orderData),
            // builder: (_) => CashOnDeliveryPage(orderData: orderData),
          ),
        );
      } else {
        final totalAmount = orderData['totalAmount'];

        if (totalAmount == null || totalAmount <= 0) {
          _showError("⚠️ Invalid total amount");
          return;
        }

        Map<String, dynamic> razorResponse = await ApiServices().razorPayApi(
          totalAmount,
          orderData['orderId'],
        );

        if (razorResponse["status"] == "success" &&
            razorResponse["body"]?["id"] != null) {
          orderData['razorpayOrderId'] = razorResponse["body"]["id"];
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewOrderPage(orderData: orderData),
              // builder: (_) => PaymentProcessingPage(orderData: orderData),
            ),
          );
        } else {
          _showError("⚠️ Unable to start payment — Try again");
        }
      }
    } catch (e) {
      _showError('Failed to proceed: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ToastUtils.showError(msg);
    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: parchmentBg,
      appBar: AppBar(
        title: const Text(
          "Payment Method",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: loadingMethods
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepperHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Choose how you'd like to pay",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (allowedMethods.isEmpty)
                          const Center(
                            child: Text(
                              "No payment methods allowed for these items.",
                            ),
                          )
                        else
                          ...allowedMethods.map((m) => _buildPaymentCard(m)),
                        const SizedBox(height: 30),
                        _buildSummaryMiniCard(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPaymentCard(String methodId) {
    final ui =
        methodUI[methodId] ??
        {
          'title': methodId.toUpperCase(),
          'subtitle': 'Proceed with $methodId',
          'icon': Icons.payment,
        };
    bool isSelected = selectedMethod == methodId;

    return GestureDetector(
      onTap: () => setState(() => selectedMethod = methodId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgGradientEnd,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                ui['icon'],
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ui['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    ui['subtitle'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: methodId,
              groupValue: selectedMethod,
              activeColor: AppTheme.primaryGreen,
              onChanged: (v) => setState(() => selectedMethod = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      color: AppTheme.bgGradientEnd,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem("1", "Details", true, true),
          _stepLine(true),
          _stepItem("2", "Payment", true, false),
          _stepLine(false),
          _stepItem("3", "Review", false, false),
        ],
      ),
    );
  }

  Widget _stepItem(String num, String label, bool active, bool completed) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: completed
              ? AppTheme.primaryGreen
              : (active ? AppTheme.primaryGreen : Colors.grey[300]),
          child: completed
              ? const Icon(Icons.check, size: 14, color: AppTheme.bgGradientEnd)
              : Text(
                  num,
                  style: const TextStyle(
                    color: AppTheme.bgGradientEnd,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppTheme.primaryGreen : AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(
      height: 2,
      color: active ? AppTheme.primaryGreen : Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 15),
    ),
  );

  Widget _buildSummaryMiniCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Colors.brown),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Total Amount to Pay: ₹${widget.orderData['totalAmount']}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, const Color(0xFF5A916E)],
              ),
            ),
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _proceedPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: isSubmitting
                  ? const CircularProgressIndicator(
                      color: AppTheme.bgGradientEnd,
                    )
                  : const Text(
                      "Proceed to Checkout",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.bgGradientEnd,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
