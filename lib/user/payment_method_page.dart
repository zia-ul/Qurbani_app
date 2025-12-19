import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_processing_page.dart';

class PaymentMethodPage extends StatefulWidget {
  /// Full order data passed from ProceedPage
  final Map<String, dynamic> orderData;

  const PaymentMethodPage({
    super.key,
    required this.orderData,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  String selectedMethod = 'online';
  bool isSubmitting = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _proceedPayment() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    try {
      /// Clone order data to avoid mutation issues
      final Map<String, dynamic> orderData =
          Map<String, dynamic>.from(widget.orderData);

      /// Add selected payment method
      orderData['paymentMethod'] = selectedMethod;

      /// Create order ID only once
      final orderRef = _firestore.collection('orders').doc();
      orderData['orderId'] = orderRef.id;

      /// Save full order before proceeding to payment
      await orderRef.set(orderData);

      if (!mounted) return;

      /// Navigate to payment processing page with full order data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentProcessingPage(
            orderData: orderData,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $e')),
      );
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Payment Method"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RadioListTile<String>(
              value: 'online',
              groupValue: selectedMethod,
              onChanged: (v) => setState(() => selectedMethod = v!),
              title: const Text("Online Payment"),
            ),
            RadioListTile<String>(
              value: 'cash',
              groupValue: selectedMethod,
              onChanged: (v) => setState(() => selectedMethod = v!),
              title: const Text("Cash on Delivery"),
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



// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'payment_processing_page.dart';

// class PaymentMethodPage extends StatefulWidget {
//   final Map<String, dynamic> orderData; // FULL order data

//   const PaymentMethodPage({
//     super.key,
//     required this.orderData,
//   });

//   @override
//   State<PaymentMethodPage> createState() => _PaymentMethodPageState();
// }

// class _PaymentMethodPageState extends State<PaymentMethodPage> {
//   String selectedMethod = 'online';
//   bool isSubmitting = false;

//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Future<void> _proceedPayment() async {
//     if (isSubmitting) return;
//     setState(() => isSubmitting = true);

//     try {
//       /// 🔹 Clone order data to avoid mutation bugs
//       final Map<String, dynamic> orderData =
//           Map<String, dynamic>.from(widget.orderData);

//       /// 🔹 Add payment method
//       orderData['paymentMethod'] = selectedMethod;

//       /// 🔹 Create order ID only ONCE
//       final orderRef = _firestore.collection('orders').doc();
//       orderData['orderId'] = orderRef.id;

//       /// 🔹 Save full order BEFORE payment
//       await orderRef.set(orderData);

//       if (!mounted) return;

//       /// 🔹 Pass FULL order data to next page
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => PaymentProcessingPage(
//             orderData: orderData, // 👈 FULL DATA PASSED
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to save order: $e')),
//       );
//       setState(() => isSubmitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Select Payment Method"),
//         backgroundColor: Colors.green,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             RadioListTile<String>(
//               value: 'online',
//               groupValue: selectedMethod,
//               onChanged: (v) => setState(() => selectedMethod = v!),
//               title: const Text("Online Payment"),
//             ),
//             RadioListTile<String>(
//               value: 'cash',
//               groupValue: selectedMethod,
//               onChanged: (v) => setState(() => selectedMethod = v!),
//               title: const Text("Cash on Delivery"),
//             ),
//             const SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: isSubmitting ? null : _proceedPayment,
//               child: isSubmitting
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : const Text("Continue"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
