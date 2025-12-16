import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({super.key, required this.userId});

  @override
  State<BookedPage> createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> get bookingsStream {
    // If using top-level bookings collection:
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: widget.userId)
        .where('payment_status', isEqualTo: 'paid')
        .orderBy('created_at', descending: true)
        .snapshots();

    // If using subcollection under users:
    // return _firestore
    //     .collection('users')
    //     .doc(widget.userId)
    //     .collection('bookings')
    //     .where('payment_status', isEqualTo: 'paid')
    //     .orderBy('created_at', descending: true)
    //     .snapshots();
  }

  Widget buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final cartItems = List<Map<String, dynamic>>.from(data['cart_items'] ?? []);
    final shareholders = List<Map<String, dynamic>>.from(data['shareholders'] ?? []);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Booking ID: ${doc.id}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text("Qurbani Day: ${data['qurbani_day'] ?? 'N/A'}"),
            Text("Contact: ${data['contact_details'] ?? 'N/A'}"),
            Text("Address: ${data['delivery_address'] ?? 'N/A'}"),
            const SizedBox(height: 10),
            const Text("Shareholders:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...shareholders.map((s) => Text("• ${s['name']} (Parent: ${s['parentName'] ?? 'N/A'})")),
            const SizedBox(height: 10),
            const Text("Cart Items:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...cartItems.map((c) => Text("• Animal ID: ${c['animalId']}, Qty: ${c['qty']}")),
            const SizedBox(height: 10),
            Text("Payment Status: ${data['payment_status'] ?? 'N/A'}"),
            Text("Processing: ${data['processing_status'] ?? 'N/A'}"),
            Text("Delivery: ${data['delivery_status'] ?? 'N/A'}"),
            const SizedBox(height: 10),
            Text(
              "Created At: ${data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : 'N/A'}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No successful bookings found.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) => buildBookingCard(bookings[index]),
          );
        },
      ),
    );
  }
}
