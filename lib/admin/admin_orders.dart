import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qurbani1/admin/admin_order_details.dart';

/// =======================
/// ADMIN ORDERS PAGE
/// =======================
class AdminOrdersPage extends StatefulWidget {
  final String adminId;

  const AdminOrdersPage({super.key, required this.adminId});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  String processingFilter = 'All';
  String deliveryFilter = 'All';

  DateTime? fromDate;
  DateTime? toDate;

  /// 🔄 UPDATED STATUSES
  final List<String> processingOptions = [
    'All',
    'Pending',
    'Qurbani Started',
    'Qurbani Done',
    'Meat Processing & Packaging',
    'Completed',
    'Cancelled',
  ];

  final List<String> deliveryOptions = [
    'All',
    'Pending',
    'Assigned to Delivery Boy',
    'Sent for Delivery',
    'Delivery Done',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    return FirebaseFirestore.instance
        .collection('admin_orders')
        .where('adminId', isEqualTo: widget.adminId)
        .snapshots();
  }

  /// 🔍 FILTER + SORT
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _processOrders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var filtered = docs.where((d) {
      final data = d.data();

      final processingOk =
          processingFilter == 'All' ||
          data['processing_status'] == processingFilter;

      final deliveryOk =
          deliveryFilter == 'All' || data['delivery_status'] == deliveryFilter;

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      final fromOk =
          fromDate == null ||
          (createdAt != null && createdAt.isAfter(fromDate!));
      final toOk =
          toDate == null || (createdAt != null && createdAt.isBefore(toDate!));

      return processingOk && deliveryOk && fromOk && toOk;
    }).toList();

    /// 🔝 Priority (latent orders first)
    int priority(String s) {
      switch (s) {
        case 'Pending':
          return 0;
        case 'Qurbani Started':
          return 1;
        case 'Qurbani Done':
          return 2;
        case 'Meat Processing & Packaging':
          return 3;
        case 'Completed':
          return 4;
        default:
          return 5;
      }
    }

    filtered.sort((a, b) {
      final p = priority(
        a['processing_status'] ?? '',
      ).compareTo(priority(b['processing_status'] ?? ''));
      if (p != 0) return p;

      final at = a['createdAt'] as Timestamp?;
      final bt = b['createdAt'] as Timestamp?;
      return (bt?.compareTo(at ?? Timestamp.now())) ?? 0;
    });

    return filtered;
  }

  /// 📤 EXPORT CSV
  Future<void> exportCSV(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln(
      'OrderID, ProcessingStatus, DeliveryStatus, PaymentStatus, TotalAmount, CreatedAt',
    );

    for (var d in docs) {
      final data = d.data();

      buffer.writeln(
        '${d.id},'
        '${data['processing_status'] ?? ''},'
        '${data['delivery_status'] ?? ''},'
        '${data['payment_status'] ?? ''},'
        '${data['total_amount'] ?? ''},'
        '${(data['createdAt'] as Timestamp?)?.toDate() ?? ''}',
      );
    }

    // ✅ SAFE location (always works)
    final dir = await getApplicationDocumentsDirectory();

    final fileName = 'orders_${DateTime.now().millisecondsSinceEpoch}.csv';

    final file = File('${dir.path}/$fileName');

    await file.writeAsString(buffer.toString());

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV downloaded successfully'),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () {
            OpenFilex.open(file.path);
          },
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Pending':
        return Colors.orange;
      case 'Qurbani Started':
        return Colors.deepOrange;
      case 'Qurbani Done':
        return Colors.blue;
      case 'Meat Processing & Packaging':
        return Colors.indigo;
      case 'Completed': // Separate color for completed
        return Colors.green.shade700;
      case 'Delivery Done':
        return Colors.green; // Slightly different green
      case 'Sent for Delivery':
        return Colors.teal;
      case 'Assigned to Delivery Boy':
        return Colors.purple;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isNewOrder(Timestamp? ts) {
    if (ts == null) return false;
    return DateTime.now().difference(ts.toDate()).inHours < 24;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final snap = await _ordersStream().first;
              await exportCSV(snap.docs);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final processed = _processOrders(snapshot.data!.docs);
          if (processed.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          final total = snapshot.data!.docs.length;
          final pending = snapshot.data!.docs
              .where((e) => e['processing_status'] == 'Pending')
              .length;
          final processing = snapshot.data!.docs
              .where((e) => e['processing_status'] == 'Qurbani Started')
              .length;
          final delivered = snapshot.data!.docs
              .where((e) => e['delivery_status'] == 'Delivery Done')
              .length;

          return Column(
            children: [
              _SummaryRow(
                total: total,
                pending: pending,
                processing: processing,
                delivered: delivered,
              ),

              _FilterBar(
                processingOptions: processingOptions,
                deliveryOptions: deliveryOptions,
                processingFilter: processingFilter,
                deliveryFilter: deliveryFilter,
                onProcessingChanged: (v) =>
                    setState(() => processingFilter = v),
                onDeliveryChanged: (v) => setState(() => deliveryFilter = v),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: processed.length,
                  itemBuilder: (context, index) {
                    final d = processed[index];
                    final data = d.data();
                    final isNew = _isNewOrder(data['createdAt']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          'Order ID: ${d.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isNew)
                              const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Wrap(
                              spacing: 6,
                              children: [
                                Chip(
                                  label: Text(
                                    data['processing_status'] ?? 'N/A',
                                  ),
                                  backgroundColor: _statusColor(
                                    data['processing_status'] ?? '',
                                  ).withOpacity(.15),
                                ),
                                Chip(
                                  label: Text(data['delivery_status'] ?? 'N/A'),
                                  backgroundColor: _statusColor(
                                    data['delivery_status'] ?? '',
                                  ).withOpacity(.15),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigate to order detail page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminOrderDetailPage(
                                orderId: d.id,
                                orderData: data,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// =======================
/// SUMMARY ROW
/// =======================
class _SummaryRow extends StatelessWidget {
  final int total;
  final int pending;
  final int processing;
  final int delivered;

  const _SummaryRow({
    required this.total,
    required this.pending,
    required this.processing,
    required this.delivered,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('Total', total),
            _stat('Pending', pending),
            _stat('Processing', processing),
            _stat('Delivered', delivered),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}

/// =======================
/// FILTER BAR
/// =======================
class _FilterBar extends StatelessWidget {
  final List<String> processingOptions;
  final List<String> deliveryOptions;
  final String processingFilter;
  final String deliveryFilter;
  final ValueChanged<String> onProcessingChanged;
  final ValueChanged<String> onDeliveryChanged;

  const _FilterBar({
    required this.processingOptions,
    required this.deliveryOptions,
    required this.processingFilter,
    required this.deliveryFilter,
    required this.onProcessingChanged,
    required this.onDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: isSmallScreen
          ? Column(
              children: [
                _processingDropdown(),
                const SizedBox(height: 8),
                _deliveryDropdown(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _processingDropdown()),
                const SizedBox(width: 8),
                Expanded(child: _deliveryDropdown()),
              ],
            ),
    );
  }

  Widget _processingDropdown() {
    return DropdownButtonFormField<String>(
      value: processingFilter,
      isExpanded: true, // ✅ FIX
      decoration: const InputDecoration(
        labelText: 'Status of Processing',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: processingOptions.map((e) {
        return DropdownMenuItem(
          value: e,
          child: Text(
            e,
            overflow: TextOverflow.ellipsis, // ✅ FIX
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: (v) => onProcessingChanged(v!),
    );
  }

  Widget _deliveryDropdown() {
    return DropdownButtonFormField<String>(
      value: deliveryFilter,
      isExpanded: true, // ✅ FIX
      decoration: const InputDecoration(
        labelText: 'Status of Delivery',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: deliveryOptions.map((e) {
        return DropdownMenuItem(
          value: e,
          child: Text(
            e,
            overflow: TextOverflow.ellipsis, // ✅ FIX
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: (v) => onDeliveryChanged(v!),
    );
  }
}
