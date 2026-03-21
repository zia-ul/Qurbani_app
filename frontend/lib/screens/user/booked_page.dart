import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/screens/user/product_details_page.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/theme/theme.dart';

class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({super.key, required this.userId});

  @override
  State<BookedPage> createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  String searchQuery = "";
  String selectedStatus = "All";

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _isCodExpired(Map<String, dynamic> order) {
    final paymentMethod = _parseInt(order['payment_method']);
    print("checking order status...$order if expired");

    final rawPaymentStatus = order['payment_status'];
    bool isNotPaid = false;

    if (rawPaymentStatus is String) {
      final normalized = rawPaymentStatus.toLowerCase().trim();
      isNotPaid = normalized == 'unpaid' || normalized == 'pending';
    } else {
      final paymentStatus = _parseInt(rawPaymentStatus, fallback: 2);
      isNotPaid = paymentStatus == 1 || paymentStatus == 2;
    }

    if (paymentMethod != 0) return false; // Not Cash
    if (!isNotPaid) return false;
    if (order['cod_deadline'] == null) return false;

    final deadline = DateTime.tryParse(order['cod_deadline'].toString());
    if (deadline == null) return false;

    return DateTime.now().isAfter(deadline);
  }

  Future<void> fetchOrders() async {
    setState(() => isLoading = true);

    try {
      orders = await OrderService.getUserOrders();
      // print("print orders...$orders");

      //cancel order
      for (final order in orders) {
        final orderStatus = _parseInt(order['status']);
        // print("print order status...$orderStatus, ${_isCodExpired(order)}");

        if (_isCodExpired(order) && orderStatus != 2) {
          print("print order status...if order expired $order");
          // print("$order");
          await OrderService.cancelOrder(order['id']);
        }
      }

      orders = await OrderService.getUserOrders();
    } catch (e) {
      debugPrint("Failed to fetch orders: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get filteredOrders {
    return orders.where((order) {
      final orderId = (order['id'] ?? '').toString().toLowerCase();
      final derivedStatus = _resolveOrderStatus(order);

      final matchesSearch = orderId.contains(searchQuery.toLowerCase());

      final matchesStatus =
          selectedStatus == 'All' ||
          derivedStatus.toLowerCase() == selectedStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _resolvePaymentStatus(Map<String, dynamic> order) {
    final raw = order['order_payment_status'];

    if (raw is String) {
      final normalized = raw.toLowerCase().trim();
      if (normalized == 'paid') return 'Paid';
      if (normalized == 'unpaid') return 'Unpaid';
      return 'Pending';
    }

    final paymentStatus = _parseInt(raw, fallback: 2);

    switch (paymentStatus) {
      case 0:
        return 'Paid';
      case 1:
        return 'Unpaid';
      case 2:
      default:
        return 'Pending';
    }
  }

  String _resolveOrderStatus(Map<String, dynamic> order) {
    if (_isCodExpired(order)) {
      return 'Cancelled';
    }

    final orderStatus = _parseInt(order['status']);

    switch (orderStatus) {
      case 2:
        return 'Cancelled';
      case 1:
        return 'Completed';
      case 0:
      default:
        return 'Active';
    }
  }

  String _resolvePaymentMethod(Map<String, dynamic> order) {
    final paymentMethod = _parseInt(order['payment_method']);

    switch (paymentMethod) {
      case 0:
        return 'Cash';
      case 1:
        return 'Online';
      default:
        return 'Unknown';
    }
  }

  Widget _statusBadge(String label) {
    Color bgColor;

    switch (label.toLowerCase()) {
      case 'completed':
        bgColor = Colors.green;
        break;
      case 'cancelled':
        bgColor = AppTheme.warningRed;
        break;
      case 'active':
        bgColor = Colors.orange;
        break;
      default:
        bgColor = AppTheme.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.bgGradientEnd,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actionBtn(VoidCallback onTap) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffE8F2E8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text(
          "View >",
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    Map<String, Map<String, dynamic>> adminMap,
  ) {
    final cartItems = order['items'] ?? [];
    final orderDate = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final String pStatus = _resolveOrderStatus(order);
    final String paymentStatus = _resolvePaymentStatus(order);
    final String paymentMethod = _resolvePaymentMethod(order);

    final String orderIdStr = (order['id'] ?? '').toString();
    final String displayId = orderIdStr.length >= 5
        ? orderIdStr.substring(0, 5).toUpperCase()
        : orderIdStr.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffFDFBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffD1C4A9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "QB-$displayId",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _statusBadge(pStatus),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Payment: $paymentStatus",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: Colors.brown,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        paymentMethod,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.brown,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      orderDate != null
                          ? DateFormat('dd MMM').format(orderDate)
                          : 'N/A',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffD1C4A9)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: _actionBtn(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      orderId: order['id'].toString(),
                      userId: widget.userId,
                    ),
                  ),
                );
              }),
            ),
          ),
          ...cartItems.map((item) => _buildItemRow(item, {}, order)).toList(),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item,
    Map<String, dynamic> admin,
    Map<String, dynamic> orderData,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item['photoUrl'] != null
                ? Image.network(
                    item['photoUrl'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: const Icon(Icons.pets, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${item['animalType'] ?? 'Animal'} - ${item['breed'] ?? 'N/A'}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _actionBtn(() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsPage(
                  orderId: orderData['id'].toString(),
                  userId: widget.userId,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgGradientEnd,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: ["All", "Active", "Completed", "Cancelled"].map((s) {
                  return DropdownMenuItem(value: s, child: Text("Status: $s"));
                }).toList(),
                onChanged: (val) => setState(() => selectedStatus = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgGradientStart,
      appBar: AppBar(
        title: const Text(
          "My Qurbani Bookings",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Track your Qurbani orders and status in real time.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          _buildSearchAndFilter(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : filteredOrders.isEmpty
                ? const Center(
                    child: Text("You have not placed any orders yet."),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: filteredOrders.length,
                    itemBuilder: (_, i) =>
                        _buildOrderCard(filteredOrders[i], {}),
                  ),
          ),
        ],
      ),
    );
  }
}
