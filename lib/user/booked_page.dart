import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/special_request.dart';

class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({super.key, required this.userId});

  @override
  State<BookedPage> createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> get ordersStream {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final cartItems = List<Map<String, dynamic>>.from(data['cartItems'] ?? []);
    final shareholders = List<Map<String, dynamic>>.from(data['shareholders'] ?? []);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order ID",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  data['orderId'] ?? doc.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const Divider(),

            /// 🔹 BASIC INFO
            _row("Qurbani Day", data['qurbaniDay']),
            _row("Amount", "₹ ${data['totalAmount']}"),
            _row("Payment", data['paymentStatus']),
            _row("Processing", data['processingStatus']),
            _row("Delivery", data['deliveryStatus']),

            const SizedBox(height: 12),

            /// 🔹 CONTACT
            _row("Contact", data['contactDetails']),
            _row("Address", data['deliveryAddress']),

            const SizedBox(height: 12),

            /// 🔹 SHAREHOLDERS
            const Text(
              "Shareholders",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...shareholders.map(
              (s) => Text(
                "• ${s['name']} (${s['gender']}) — ${s['animalType']}",
              ),
            ),

            const SizedBox(height: 12),

            /// 🔹 CART ITEMS
            const Text(
              "Animals Purchased",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...cartItems.map(
              (c) => Text(
                "• ${c['title']} — Shares: ${c['shares']} — ₹${c['price']}",
              ),
            ),

            const SizedBox(height: 12),

            /// 🔹 DATE
            Text(
              "Ordered on: ${data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : ''}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 16),

            /// 🔹 SPECIAL REQUEST BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text("Special Request"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpecialRequestPage(orderData: data),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$title:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders History"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "You have not placed any orders yet.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (_, i) => _buildOrderCard(orders[i]),
          );
        },
      ),
    );
  }
}
