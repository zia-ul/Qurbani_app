import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// delivery status filter
  String _statusFilter = 'all'; // all | pending | delivered

  /// Orders assigned to delivery person
  Stream<QuerySnapshot> get assignedOrders {
    return _firestore
        .collection('admin_orders')
        .where('delivery_person_id', isEqualTo: widget.deliveryId)
        .snapshots();
  }

  /// Logout
  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
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
    final deliveryStatus =
        (data['delivery_status'] ?? 'pending').toString().toLowerCase();
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
          Text("Customer ID: ${data['userId'] ?? 'Unknown'}"),
          Text("Delivery Address: ${data['delivery_address'] ?? 'N/A'}"),
          Text("Contact: ${data['contact_details'] ?? 'N/A'}"),
          const SizedBox(height: 6),

          const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
          ...cartItems.map((item) {
            final map = item as Map<String, dynamic>;
            return Text(
              "${map['name'] ?? 'Item'} x${map['qty'] ?? 0}",
            );
          }),

          const SizedBox(height: 6),
          Text("Status: $deliveryStatus"),

          if (deliveredAt != null)
            Text(
              "Delivered at: ${deliveredAt.toDate()}",
              style: const TextStyle(color: Colors.green),
            ),

          const SizedBox(height: 10),

          deliveryStatus == 'pending'
              ? ElevatedButton(
                  onPressed: () => markAsDelivered(doc.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Mark as Delivered"),
                )
              : const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 🍔 HAMBURGER MENU
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.green),
              accountName: Text(widget.name),
              accountEmail: const Text("Delivery Partner"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.delivery_dining, color: Colors.green),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: Text("Welcome, ${widget.name}"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),

      body: Column(
        children: [
          /// 🔹 FILTER BAR
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _filterChip("All", 'all'),
                _filterChip("Pending", 'pending'),
                _filterChip("Delivered", 'delivered'),
              ],
            ),
          ),

          /// 🔹 ORDERS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: assignedOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No orders assigned"));
                }

                /// Apply filter
                final orders = snapshot.data!.docs.where((doc) {
                  final status =
                      (doc['delivery_status'] ?? 'pending').toString();
                  if (_statusFilter == 'all') return true;
                  return status.toLowerCase() == _statusFilter;
                }).toList();

                if (orders.isEmpty) {
                  return const Center(child: Text("No orders found"));
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (_, i) => buildOrderItem(orders[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔘 Filter Chip
  Widget _filterChip(String label, String value) {
    final bool selected = _statusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Colors.green,
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
      ),
    );
  }
}
