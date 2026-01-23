import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/services/user_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;
  late String processing;
  late String? delivery;
  String? selectedDeliveryBoyId;
  DateTime? qurbaniDate;
  TimeOfDay? qurbaniTime;

  final List<String> processingOptions = ['pending', 'confirmed', 'completed'];

  final List<String> deliveryOptions = ['pending', 'sent', 'delivered'];

  List<Map<String, dynamic>> deliveryBoys = [];
  bool loadingDeliveryBoys = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchDeliveryBoys();
  }

   Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
      print("Order Data Admin: $orderData");
      print("Order Data: $orderData");
      // Initialize dropdown values
      final p = orderData!['processing_status'] ?? processingOptions[0];
      processing = processingOptions.contains(p) ? p : processingOptions[0];

      final d = orderData!['delivery_status'] ?? deliveryOptions[0];
      delivery = deliveryOptions.contains(d) ? d : deliveryOptions[0];

      selectedDeliveryBoyId = orderData!['delivery_person_id'];
    } catch (e) {
      print("...............$e");
      ToastUtils.showError('Failed to load order details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Future<void> _fetchOrderDetails() async {
  //   try {
  //     print("Fetching order details for ID: ${widget.orderId}"); // Add this
  //     orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
  //     print("Order Data: $orderData"); // Existing print
  //     // ... rest
  //   } catch (e) {
  //     print("Error fetching order: $e"); // Add this for full error details
  //     ToastUtils.showError('Failed to load order details: $e');
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

  Future<void> _fetchDeliveryBoys() async {
    try {
      deliveryBoys =
          await UserService.getDeliveryBoys(); // UPDATED: Use UserService
    } catch (e) {
      ToastUtils.showError('Failed to load delivery boys: $e');
    } finally {
      setState(() => loadingDeliveryBoys = false);
    }
  }

  Future<void> save() async {
    if (processing == 'pending') {
      if (qurbaniDate == null || qurbaniTime == null) {
        ToastUtils.showError('Qurbani date and time are required to continue.');
        return;
      }
    }

    try {
      DateTime? combinedDateTime;
      if (qurbaniDate != null && qurbaniTime != null) {
        combinedDateTime = DateTime(
          qurbaniDate!.year,
          qurbaniDate!.month,
          qurbaniDate!.day,
          qurbaniTime!.hour,
          qurbaniTime!.minute,
        );
      }

      // Make sure all keys have either value or null
      final body = {
        // 'delivery_status': delivery ?? null,
        'delivery_person_id': selectedDeliveryBoyId ?? null,
        'qurbani_time': combinedDateTime?.toIso8601String() ?? null,
      };

      print("DEBUG: Updating order ${widget.orderId} with body: $body");
      await AdminOrderService.updateOrder(widget.orderId, body);

      ToastUtils.showSuccess('Order updated successfully');
    } catch (e) {
      ToastUtils.showError('Failed to update order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (orderData == null) {
      return const Scaffold(body: Center(child: Text('Failed to load order')));
    }

    final data = orderData!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('Order ID', widget.orderId),
            _buildRow('User Name', data['user_name'] ?? 'N/A'),
            _buildRow('Animal Type', data['animal_type'] ?? 'N/A'),
            _buildRow('Parts', (data['parts'] as String?) ?? 'N/A'),
            _buildRow('Price', data['total_amount']?.toString() ?? 'N/A'),
            _buildRow('Payment Status', data['payment_status'] ?? 'N/A'),
            _buildRow('Delivery Address', data['delivery_address'] ?? 'N/A'),
            _buildRow('Contact', data['contact_no'] ?? 'N/A'),
            const SizedBox(height: 16),
            if (processing == 'pending') ...[
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => qurbaniDate = picked);
                  }
                },
                child: Text(
                  qurbaniDate == null
                      ? 'Select Qurbani Date'
                      : 'Date: ${qurbaniDate!.toLocal().toString().split(' ')[0]}',
                ),
              ),

              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() => qurbaniTime = picked);
                  }
                },
                child: Text(
                  qurbaniTime == null
                      ? 'Select Qurbani Time'
                      : 'Time: ${qurbaniTime!.format(context)}',
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Processing Status
            Chip(
              label: Text(processing.toUpperCase()),
              backgroundColor: processing == 'pending'
                  ? Colors.orange.shade100
                  : processing == 'confirmed'
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
            ),

            const SizedBox(height: 12),

            // Delivery Status
            // DropdownButtonFormField<String>(
            //   value: delivery,
            //   decoration: const InputDecoration(
            //     labelText: 'Delivery Status',
            //     border: OutlineInputBorder(),
            //   ),
            //   items: deliveryOptions
            //       .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            //       .toList(),
            //   onChanged: (v) => setState(() => delivery = v!),
            // ),
            // const SizedBox(height: 12),

            // Assign Delivery Boy
            loadingDeliveryBoys
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<String>(
                    value: selectedDeliveryBoyId,
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

            // Delivery Boy Profile Card (shown if selected)
            if (selectedDeliveryBoyId != null) ...[
              const SizedBox(height: 16),
              _buildDeliveryBoyCard(),
            ],

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

  Widget _buildDeliveryBoyCard() {
    final deliveryBoy = deliveryBoys.firstWhere(
      (boy) => boy['id'] == selectedDeliveryBoyId,
      orElse: () => {'name': 'Unknown', 'phone': 'N/A', 'address': 'N/A'},
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Delivery Person',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRow('Name', deliveryBoy['name']),
            _buildRow('Phone', deliveryBoy['phone'] ?? 'N/A'),
            _buildRow('Address', deliveryBoy['address'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}
