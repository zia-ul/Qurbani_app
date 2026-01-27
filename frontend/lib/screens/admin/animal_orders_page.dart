import 'package:Qurbani/screens/admin/animal_edit.dart';
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
                      Text("User: ${order['order_id']}"),
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
