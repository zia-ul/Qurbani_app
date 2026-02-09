// services/admin_order_service.dart
import 'package:Qurbani/services/admin_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';

class AdminDeliveryRequestsPage extends StatefulWidget {
  const AdminDeliveryRequestsPage({super.key});

  @override
  State<AdminDeliveryRequestsPage> createState() =>
      _AdminDeliveryRequestsPageState();
}

class _AdminDeliveryRequestsPageState
    extends State<AdminDeliveryRequestsPage> {
  late Future<List<dynamic>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = AdminService.getDeliveryRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Requests"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(child: Text("No requests in your area"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (_, i) => _buildRequestCard(requests[i]),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r['name'],
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("📞 ${r['phone']}"),
            Text("📍 ${r['city']}, ${r['state']}"),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(r['id'], "APPROVED"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Approve"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(r['id'], "REJECTED"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text("Reject"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    await AdminService.updateDeliveryRequest(id, status);
    setState(() {
      _requestsFuture = AdminService.getDeliveryRequests();
    });
  }
}
