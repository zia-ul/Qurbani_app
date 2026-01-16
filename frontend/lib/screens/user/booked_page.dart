import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/screens/user/product_details_page.dart';
import 'package:Qurbani/screens/user/currency_notifier.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/theme/theme.dart';

class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({super.key, required this.userId});

  @override
  State<BookedPage> createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  // Orders fetched from API via OrderService
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  // Search and Filter State
  String searchQuery = "";
  String selectedStatus = "All";

  static const Color primaryGreen = AppTheme.primaryGreen;
  static const Color parchmentBg = Color(0xffF2E8D5);

  @override
  void initState() {
    super.initState();
    // currencyNotifier.addListener(_onCurrencyChanged);
    fetchOrders();
  }

  @override
  void dispose() {
    // currencyNotifier.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Use OrderService instead of direct http calls
      orders = await OrderService.getUserOrders();
    } catch (e) {
      print('Exception fetching orders: $e');
      // Optionally show a snackbar or dialog for errors
    } finally {
      if (mounted)
        setState(() {
          isLoading = false;
        });
    }
  }

  List<Map<String, dynamic>> get filteredOrders {
    return orders.where((order) {
      final orderId = (order['orderId'] ?? '').toString().toLowerCase();
      final status = (order['processingStatus'] ?? 'Pending').toString();
      final matchesSearch = orderId.contains(searchQuery.toLowerCase());
      final matchesStatus = selectedStatus == "All" || status == selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: parchmentBg,
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
                    itemBuilder: (_, i) => _buildOrderCard(
                      filteredOrders[i],
                      {},
                    ), // adminMap still empty; access admin data from order if needed
                  ),
          ),
        ],
      ),
    );
  }

  //search bar
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search Order ID...",
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: ["All", "Pending", "Completed", "Processing"].map((s) {
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

  //ui for each order cards
  Widget _buildOrderCard(
    Map<String, dynamic> order,
    Map<String, Map<String, dynamic>> adminMap,
  ) {
    final cartItems = order['items'] ?? [];
    final orderDate = DateTime.tryParse(order['createdAt'] ?? '');
    final String pStatus = order['processingStatus'] ?? 'Pending';
    print(cartItems);
    // Safely handle orderId for display
    String orderIdStr = (order['id'] ?? '').toString();
    String displayId = orderIdStr.length >= 5
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
                        "ID: QB-${displayId}",
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
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${order['paymentStatus'] ?? 'Paid'}",
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Delivery: ${order['deliveryStatus'] ?? 'Pending'}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getDeliveryStatusColor(
                            order['deliveryStatus'] ?? 'Pending',
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (order['deliveryStatus'] == 'sent' &&
                        order['deliveryCode'] != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.vpn_key,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Code: ${order['deliveryCode']}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffD1C4A9)),
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
                      orderId: order['id'],
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

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
                // Text(
                //   "Price: ${UserCurrency.currency} ${UserCurrency.convert(item['price'] ?? 0).toStringAsFixed(2)}",
                //   style: const TextStyle(fontSize: 11, color: Colors.black54),
                // ),
              ],
            ),
          ),
          _actionBtn(() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsPage(
                  orderId: orderData['id'],
                  userId: widget.userId,
                ),
              ),
            );
          }),
        ],
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

  Color _getDeliveryStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.black54;
    }
  }
}
