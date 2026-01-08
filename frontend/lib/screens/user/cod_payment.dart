import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/user/payment_success_page.dart';

class CashOnDeliveryPage extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CashOnDeliveryPage({super.key, required this.orderData});

  Future<void> _clearCart(String userId) async {
    final cartRef = _firestore.collection('carts').doc(userId);
    final items = await cartRef.collection('items').get();

    // Delete all items in the user's cart
    for (var doc in items.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prepare order data for COD
    final codOrderData = Map<String, dynamic>.from(orderData);
    codOrderData['paymentMethod'] = 'cod';
    codOrderData['paymentStatus'] = 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cash on Delivery"),
        backgroundColor: Color(0xff537D4F),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Empty the cart first
            final userId = codOrderData['userId'] as String;
            await _clearCart(userId);

            // Navigate to PaymentSuccessPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccessPage(orderData: codOrderData),
              ),
            );
          },
          child: const Text("Confirm Cash on Delivery"),
        ),
      ),
    );
  }
}
