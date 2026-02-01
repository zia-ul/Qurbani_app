import 'package:Qurbani/screens/admin/animal_edit.dart';
import 'package:Qurbani/screens/admin/barcode_page.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/theme/theme.dart';

class AnimalOrdersPage extends StatefulWidget {
  final String animalId;
  final String animalName;

  const AnimalOrdersPage({
    super.key,
    required this.animalId,
    required this.animalName,
  });

  @override
  State<AnimalOrdersPage> createState() => _AnimalOrdersPageState();
}

class _AnimalOrdersPageState extends State<AnimalOrdersPage> {
  Future<List<Map<String, dynamic>>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = OrderService.getAnimalOrders(widget.animalId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // For gradient
      appBar: AppBar(
        title: Text("Orders for ${widget.animalName}"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            AppLogger.error(
              "Failed to load orders for animalId=${widget.animalId}",
              snapshot.error,
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Text("No orders found for this animal."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order ID: ${order['order_id']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text("Payment: ${order['payment_status']}"),
                      Text("Processing: ${order['processing_status']}"),
                      Text("Delivery: ${order['delivery_status']}"),
                      Text("Date: ${order['created_at']}"),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // print("odrer.....$order['order_id']");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnimalEditPage(
                                animalId: widget.animalId,
                                orderId: order['order_id'],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Add Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.bgGradientEnd,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                      ElevatedButton.icon(
  onPressed: () async {
    try {
      // 1️⃣ Fetch full barcode from server
      final fullBarcode = await OrderService.getOrderBarcode(order['order_id']);

      // 2️⃣ Shorten barcode for display (last 12 digits)
      final displayBarcode = fullBarcode.length > 12
          ? fullBarcode.substring(fullBarcode.length - 12)
          : fullBarcode;

      // 3️⃣ Show AlertDialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Barcode for Order ${order['order_id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Scan to get user details"),
              const SizedBox(height: 12),
              BarcodeWidget(
                data: fullBarcode,
                barcode: Barcode.code128(),
                width: 200,
                height: 80,
              ),
              const SizedBox(height: 12),
              Text(
                displayBarcode, // short display
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarcodePage(barcodeValue: fullBarcode),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching barcode: $e'),
        ),
      );
    }
  },
  icon: const Icon(Icons.qr_code, size: 18),
  label: const Text('Print Barcode'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 36),
  ),
),

                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
