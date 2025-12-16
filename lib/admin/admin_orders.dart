import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// =======================
/// ADMIN ORDERS PAGE
/// =======================
class AdminOrdersPage extends StatelessWidget {
  final String adminId;

  const AdminOrdersPage({super.key, required this.adminId});

  Stream<QuerySnapshot<Map<String, dynamic>>> _fetchAdminOrders() {
    return FirebaseFirestore.instance
        .collection('admin_orders')
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings (Admin View)'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fetchAdminOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No bookings found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final orderDoc = docs[index];
              final orderData = orderDoc.data();

              final cartItems = (orderData['cart_items'] as List<dynamic>? ?? [])
                  .map((e) => (e as Map<String, dynamic>)['name'] ?? 'Unknown')
                  .join(', ');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('Order ID: ${orderDoc.id}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Items: $cartItems'),
                      Text('Processing: ${orderData['processing_status']}'),
                      Text('Delivery: ${orderData['delivery_status']}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminOrderDetailPage(
                          orderId: orderDoc.id,
                          orderData: orderData,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// =======================
/// ADMIN ORDER DETAIL PAGE
/// =======================
class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const AdminOrderDetailPage(
      {super.key, required this.orderId, required this.orderData});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late String processingStatus;
  bool isSaving = false;

  final List<String> statusOptions = [
    'Pending',
    'Processing',
    'Completed',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    // Ensure initial value exists in statusOptions to avoid crash
    final dbStatus = widget.orderData['processing_status'] ?? 'Pending';
    processingStatus = statusOptions.contains(dbStatus) ? dbStatus : 'Pending';
  }

  Future<void> saveChanges() async {
    setState(() => isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .update({'processing_status': processingStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.orderData;
    final cartItems = (orderData['cart_items'] as List<dynamic>? ?? [])
        .map((e) => (e as Map<String, dynamic>)['name'] ?? 'Unknown')
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Order ID: ${widget.orderId}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Items: $cartItems'),
            Text('Delivery Status: ${orderData['delivery_status'] ?? 'N/A'}'),
            Text('Payment Status: ${orderData['payment_status'] ?? 'N/A'}'),
            Text('Contact: ${orderData['contact_details'] ?? 'N/A'}'),
            Text('Address: ${orderData['delivery_address'] ?? 'N/A'}'),
            Text('Qurbani Day: ${orderData['qurbani_day'] ?? 'N/A'}'),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: processingStatus,
              decoration: const InputDecoration(
                labelText: 'Processing Status',
                border: OutlineInputBorder(),
              ),
              items: statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => processingStatus = val);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveChanges,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
