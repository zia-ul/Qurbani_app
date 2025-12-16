import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryHomePage extends StatefulWidget {
  final String deliveryId;
  final String name;

  const DeliveryHomePage({
    super.key,
    required this.deliveryId,
    required this.name,
  });

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of orders assigned to this delivery person
  Stream<QuerySnapshot> get assignedOrders {
    return _firestore
        .collection('admin_orders')
        .where('delivery_person_id', isEqualTo: widget.deliveryId)
        .snapshots();
  }

  /// Mark order as delivered
  Future<void> markAsDelivered(String orderId) async {
    try {
      await _firestore.collection('admin_orders').doc(orderId).update({
        'delivery_status': 'delivered',
        'delivered_at': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order marked as delivered")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update order: $e")),
      );
    }
  }

  Widget buildOrderItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final deliveryStatus = (data['delivery_status'] ?? 'pending') as String;
    final cartItems = (data['cart_items'] as List<dynamic>?) ?? [];
    final deliveredAt = data['delivered_at'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green, width: 1.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order ID: ${doc.id}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text("Customer: ${data['userId'] ?? 'Unknown'}"),
          Text("Delivery Address: ${data['delivery_address'] ?? 'N/A'}"),
          Text("Contact: ${data['contact_details'] ?? 'N/A'}"),
          const SizedBox(height: 6),
          const Text(
            "Items:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...cartItems.map((item) {
            final map = item as Map<String, dynamic>;
            return Text(
              "${map['name'] ?? 'Item'} x${map['qty'] ?? 0} - ₹${map['price'] ?? 0}",
            );
          }).toList(),
          const SizedBox(height: 6),
          Text("Status: $deliveryStatus"),
          if (deliveredAt != null)
            Text(
              "Delivered at: ${deliveredAt.toDate()}",
              style: const TextStyle(color: Colors.green),
            ),
          const SizedBox(height: 10),
          deliveryStatus.toLowerCase() == 'pending'
              ? ElevatedButton(
                  onPressed: () => markAsDelivered(doc.id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Mark as Delivered"),
                )
              : const Icon(Icons.check_circle, color: Colors.green, size: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.name}"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: assignedOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders assigned yet"));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) => buildOrderItem(orders[index]),
          );
        },
      ),
    );
  }
}
