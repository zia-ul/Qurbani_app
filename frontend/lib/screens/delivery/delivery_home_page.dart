import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:qurbani/drawer.dart';
import 'package:qurbani/services/delivery_service.dart';
import 'package:qurbani/theme/theme.dart';
import 'package:qurbani/widgets/success_error_popup.dart';

class DeliveryHomePage extends StatefulWidget {
  final String deliveryId;
  final String name;

  const DeliveryHomePage({
    super.key,
    required this.deliveryId,
    required this.name,
  });

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  String _statusFilter = 'all';
  String _searchQuery = "";
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Color lightBg = const Color(0xffF4F7F4);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _orders = await DeliveryService.getOrders();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _requestPermissionsIfNeeded() async {
    final statuses = await [
      Permission.location,
      Permission.camera,
      Permission.notification,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      ToastUtils.showError("Some permissions were denied");
    }
    return allGranted;
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      final result = await DeliveryService.updateStatus(orderId, status);
      if (status == 'sent') {
        // Show code to delivery person (backend handles user notification)
        ToastUtils.showSuccess(
          'Code sent to user: ${result['code']}',
        );

        // Local notification
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: Random().nextInt(10000),
            channelKey: 'delivery_alerts',
            title: 'Delivery Started',
            body: 'Order $orderId is on the way',
          ),
        );
      }
      _fetchOrders(); // Refresh list
    } catch (e) {
      ToastUtils.showError("Error: $e");

    }
  }

  Future<void> _verifyCode(String orderId, String code) async {
    try {
      await DeliveryService.verifyCode(orderId, code);
      Navigator.pop(context);
      ToastUtils.showSuccess("Order marked as Delivered!");
      _fetchOrders();
    } catch (e) {
      ToastUtils.showError("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      drawer: MasterDrawer(
        name: widget.name,
        id: widget.deliveryId,
        role: 'delivery',
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: AppTheme.primaryGreen),
        title: Text(
          "Delivery Dashboard",
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrders),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, ${widget.name}!",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Your Delivery Tasks",
            style: TextStyle(color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 15),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Search Order ID...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: lightBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: ['all', 'pending', 'sent', 'delivered'].map((s) {
          bool selected = _statusFilter == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                s.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: selected,
              onSelected: (v) => setState(() => _statusFilter = s),
              selectedColor: AppTheme.primaryGreen,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            ElevatedButton(onPressed: _fetchOrders, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filteredOrders = _orders.where((order) {
      final status = (order['delivery_status'] ?? 'pending').toLowerCase();
      final id = order['id'].toLowerCase();
      final matchesFilter = _statusFilter == 'all' || status == _statusFilter;
      final matchesSearch = id.contains(_searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();

    if (filteredOrders.isEmpty) {
      return const Center(child: Text("No tasks found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredOrders.length,
      itemBuilder: (context, i) => _buildOrderCard(filteredOrders[i]),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['delivery_status'] ?? 'pending').toLowerCase();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "#${order['id'].substring(0, min(8, order['id'].length)).toUpperCase()}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              _buildBadge(status),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              const Icon(Icons.pets, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                "${items.length} Items Included",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(
            Icons.location_on,
            order['delivery_address'] ?? 'No Address',
          ),
          _infoRow(Icons.person, order['customer_name'] ?? "Customer"),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(thickness: 0.5),
          ),
          const Text(
            "Seller Details",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 5),
          _infoRow(Icons.store, order['admin_name'] ?? 'Unknown Admin'),
          _infoRow(
            Icons.phone_android,
            order['admin_contact'] ?? 'No Contact Info',
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              if (status == 'pending')
                Expanded(
                  child: _actionBtn(
                    "Start Delivery",
                    Icons.play_arrow,
                    () async {
                      final hasPermissions =
                          await _requestPermissionsIfNeeded();
                      if (hasPermissions) _updateStatus(order['id'], 'sent');
                    },
                    isMain: true,
                  ),
                ),
              if (status == 'sent')
                Expanded(
                  child: _actionBtn(
                    "Verify Code",
                    Icons.vpn_key,
                    () => _showVerifyDialog(order['id']),
                    isMain: true,
                  ),
                ),
              if (status == 'delivered')
                const Expanded(
                  child: Text(
                    "✅ Order Successfully Completed",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color color = Colors.orange;
    if (status == 'sent') color = Colors.blue;
    if (status == 'delivered') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isMain = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isMain ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isMain ? Colors.white : Colors.black87),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isMain ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyDialog(String orderId) {
    TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Enter Customer Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ask the customer for the 6-digit delivery code."),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter 6-digit code",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () => _verifyCode(orderId, ctrl.text),
            child: const Text(
              "Verify & Deliver",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
