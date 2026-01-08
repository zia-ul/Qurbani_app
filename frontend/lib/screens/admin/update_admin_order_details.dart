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
    'Qurbani Started',
    'Qurbani Done',
    'Meat Processing & Packaging',
  ];

  final List<String> deliveryOptions = ['Sent for Delivery', 'Delivery Done'];

  List<Map<String, dynamic>> deliveryBoys = [];
  bool loadingDeliveryBoys = true;

  @override
  void initState() {
    super.initState();

    // Initialize dropdown values
    final p = widget.orderData['processing_status'] ?? processingOptions[0];
    processing = processingOptions.contains(p) ? p : processingOptions[0];

    final d = widget.orderData['delivery_status'] ?? deliveryOptions[0];
    delivery = deliveryOptions.contains(d) ? d : deliveryOptions[0];

    // Preselect assigned delivery boy
    selectedDeliveryBoyId = widget.orderData['delivery_person_id'];

    fetchDeliveryBoys();
  }

  Future<void> fetchDeliveryBoys() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .get();

    setState(() {
      deliveryBoys = snap.docs
          .map((doc) => {'id': doc.id, 'name': doc['name'] ?? 'No Name'})
          .toList();
      loadingDeliveryBoys = false;
    });
  }

  Future<void> save() async {
    await FirebaseFirestore.instance
        .collection('admin_orders')
        .doc(widget.orderId)
        .update({
          'processing_status': processing,
          'delivery_status': delivery,
          'delivery_person_id': selectedDeliveryBoyId,
        });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order updated')));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Color(0xff537D4F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('Order ID', widget.orderId),
            _buildRow('User Name', data['user_name'] ?? 'N/A'),
            _buildRow('Animal Type', data['animal_type'] ?? 'N/A'),
            _buildRow(
              'Parts',
              (data['parts'] as List<dynamic>?)?.join(', ') ?? 'N/A',
            ),
            _buildRow('Price', data['total_amount']?.toString() ?? 'N/A'),
            _buildRow('Payment Status', data['payment_status'] ?? 'N/A'),
            _buildRow('Delivery Address', data['delivery_address'] ?? 'N/A'),
            _buildRow('Contact', data['contact_no'] ?? 'N/A'),
            const SizedBox(height: 16),

            // Processing Status
            DropdownButtonFormField<String>(
              initialValue: processing,
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

            // Delivery Status
            DropdownButtonFormField<String>(
              initialValue: delivery,
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

            // Assign Delivery Boy
            loadingDeliveryBoys
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: selectedDeliveryBoyId,
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
                child: const Text('Save Changess'),
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
