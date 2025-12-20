import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const AdminOrderDetailPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late String processing;
  late String delivery;
  String? selectedDeliveryBoyId;

  final List<String> processingOptions = [
    'Pending',
    'Qurbani Started',
    'Qurbani Done',
    'Meat Processing & Packaging',
    'Completed',
    'Cancelled',
  ];

  final List<String> deliveryOptions = [
    'Pending',
    'Sent for Delivery',
    'Delivery Done',
  ];

  List<Map<String, dynamic>> deliveryBoys = [];
  bool loadingDeliveryBoys = true;

  @override
  void initState() {
    super.initState();

    // Initialize status values safely
    processing = processingOptions.contains(widget.orderData['processing_status'])
        ? widget.orderData['processing_status']
        : 'Pending';

    delivery = deliveryOptions.contains(widget.orderData['delivery_status'])
        ? widget.orderData['delivery_status']
        : 'Pending';

    selectedDeliveryBoyId = widget.orderData['delivery_person_id'];

    fetchDeliveryBoys();
  }

  Future<void> fetchDeliveryBoys() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .get();

      if (!mounted) return;

      setState(() {
        deliveryBoys = snap.docs
            .map((doc) => {'id': doc.id, 'name': doc['name'] ?? 'No Name'})
            .toList();
        loadingDeliveryBoys = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        deliveryBoys = [];
        loadingDeliveryBoys = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load delivery boys: $e')),
      );
    }
  }

  Future<void> save() async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .update({
        'processing_status': processing,
        'delivery_status': delivery,
        'delivery_person_id': selectedDeliveryBoyId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.orderData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('Order ID', order['orderId'] ?? 'N/A'),
            _buildRow('User Name', order['user_name'] ?? 'N/A'),
            _buildRow('Animal Type', order['animal_type'] ?? order['title'] ?? 'N/A'),
            _buildRow(
              'Parts',
              (order['parts'] as List<dynamic>?)?.join(', ') ?? 'N/A',
            ),
            _buildRow('Price', (order['total_amount'] ?? order['price'])?.toString() ?? 'N/A'),
            _buildRow('Payment Status', order['payment_status'] ?? 'N/A'),
            _buildRow('Delivery Address', order['delivery_address'] ?? 'N/A'),
            _buildRow('Contact', order['contact_no'] ?? order['contactDetails'] ?? 'N/A'),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: processing,
              decoration: const InputDecoration(
                labelText: 'Processing Status',
                border: OutlineInputBorder(),
              ),
              items: processingOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => processing = v!),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: delivery,
              decoration: const InputDecoration(
                labelText: 'Delivery Status',
                border: OutlineInputBorder(),
              ),
              items: deliveryOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => delivery = v!),
            ),
            const SizedBox(height: 12),

            loadingDeliveryBoys
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    value: deliveryBoys.any((e) => e['id'] == selectedDeliveryBoyId)
                        ? selectedDeliveryBoyId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Assign Delivery Boy',
                      border: OutlineInputBorder(),
                    ),
                    items: deliveryBoys
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['id'],
                            child: Text(e['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedDeliveryBoyId = v),
                  ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: save,
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
