import 'package:Qurbani/screens/admin/shareholder_order_details.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/theme/theme.dart';

class AdminOrdersPage extends StatefulWidget {
  final String adminId;

  const AdminOrdersPage({super.key, required this.adminId});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";
  List<Map<String, dynamic>> _allOrders = []; // Store fetched orders
  bool _isLoading = true;

  final Color lightBg = const Color(0xFFF4F7F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool isNewOrder(String createdAt) {
    final created = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    return now.difference(created).inHours < 24;
  }

  String shortId(String id, {int length = 8}) {
    if (id.length <= length) return id;
    return id.substring(id.length - length); // last N chars
  }

  bool _isCodExpired(Map<String, dynamic> order) {
    AppLogger.debug("Checking COD expiry", {
      "orderId": order['orderId'],
      "paymentMethod": order['paymentMethod'],
      "paymentStatus": order['paymentStatus'],
      "deadline": order['cod_deadline'],
    });
    if (order['paymentMethod'] != 'Cash') return false;
    if (order['paymentStatus'] != 'unpaid') return false;
    if (order['cod_deadline'] == null) return false;

    final deadline = DateTime.tryParse(order['cod_deadline']);
    print("date....$deadline, ${DateTime.now()}");
    if (deadline == null) return false;

    return DateTime.now().isAfter(deadline);
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      _allOrders = await AdminOrderService.getAdminOrders();
      print(_allOrders.length);

      AppLogger.info("Orders fetched: ${_allOrders.length}");

      // AUTO CANCEL EXPIRED COD ORDERS
      for (final order in _allOrders) {
        final isExpired = _isCodExpired(order);
        final isAlreadyCancelled = order['processingStatus'] == 'cancelled';

        print("Checking Cancelled orders");
        print(isAlreadyCancelled);
        print(isExpired);

        if (isExpired && !isAlreadyCancelled) {
          AppLogger.warning(
            "Auto-cancelling expired COD order: ${order['orderId']}",
          );
          await AdminOrderService.cancelOrder(order['orderId']);
        }
      }

      // Re-fetch to get updated statuses
      _allOrders = await AdminOrderService.getAdminOrders();
      print("testing orders after cancellation cleanup");
      print(_allOrders);

      AppLogger.info("Orders reloaded after cancellation cleanup");
    } catch (e, stack) {
      AppLogger.error("Failed to fetch admin orders", e, stack);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const Text(
          "View Orders",
          style: TextStyle(
            color: Color(0xFF2D4F32),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D4F32)),
      ),
      body: Column(
        children: [
          // 1. TABS
          Container(
            color: AppTheme.bgGradientEnd,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: AppTheme.primaryGreen,
              indicatorColor: AppTheme.primaryGreen,
              tabs: const [
                Tab(text: "Active"),
                Tab(text: "Completed"),
              ],
            ),
          ),

          // 2. SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search ID or Phone...",
                prefixIcon: const Icon(Icons.search),
                fillColor: AppTheme.bgGradientEnd,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 3. ORDER LISTS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrderList(isActive: true),
                        _buildOrderList(isActive: false),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getOverallDeliveryStatus(Map<String, dynamic> order) {
    final List shareholders = order['shareholders'] ?? [];

    if (shareholders.isEmpty) return 'Pending';

    final statuses = shareholders
        .map((s) => (s['delivery_status'] ?? '').toString().toLowerCase())
        .toList();

    if (statuses.every((s) => s == 'delivered')) {
      return 'Delivered';
    }

    if (statuses.contains('pending')) {
      return 'Pending';
    }

    if (statuses.contains('assigned')) {
      return 'Assigned';
    }

    return 'Pending';
  }

  String _getOverallProcessingStatus(Map<String, dynamic> order) {
    final List shareholders = order['shareholders'] ?? [];

    if (shareholders.isEmpty) return 'Pending';

    final statuses = shareholders
        .map((s) => (s['processing_status'] ?? '').toString().toLowerCase())
        .toList();

    if (statuses.contains('pending')) {
      return 'Pending';
    }

    if (statuses.contains('confirmed')) {
      return 'Confirmed';
    }

    if (statuses.every((s) => s == 'completed')) {
      return 'Completed';
    }

    return 'Pending';
  }

  Widget newBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "NEW",
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOrderList({required bool isActive}) {
    final filteredOrders = _allOrders.where((order) {
      final data = order;
      print("data....$data");
      // Filter by completion status - include delivered orders as completed
      final deliveryStatus = _getOverallDeliveryStatus(data);
      final processingStatus = _getOverallProcessingStatus(data);

      final isCompleted = processingStatus.toLowerCase() == 'completed';

      final isDelivered = deliveryStatus.toLowerCase() == 'delivered';

      // final isDelivered = deliveryStatus.toLowerCase() == 'delivered';
      // Show in Active: not completed AND not delivered
      // Show in Completed: completed OR delivered
      final matchesStatus = isActive
          ? (!isCompleted && !isDelivered)
          : (isCompleted || isDelivered);

      // Filter by search query
      final orderId = (data['orderId'] ?? '').toString().toLowerCase();
      final phone =
          (data['contact'] is Map
                  ? data['contact']['primary']
                  : data['contact'] ?? '')
              .toString()
              .toLowerCase();
      final matchesSearch =
          orderId.contains(_searchQuery) || phone.contains(_searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredOrders.isEmpty)
      return const Center(child: Text("No orders found"));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final data = filteredOrders[index];
        final orderId = data['orderId'] ?? '';
        final createdAt = data['createdAt'];

        final bool showNew =
            createdAt != null && isNewOrder(createdAt.toString());

        final deliveryStatus = data['deliveryStatus'] ?? 'Pending';
        final processingStatus = _isCodExpired(data)
            ? 'Cancelled'
            : _getOverallProcessingStatus(data);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgGradientEnd,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "ID: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: "#${shortId(orderId)}"),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (showNew) newBadge(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShareholderOrderDetails(orderId: orderId),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.bgGradientEnd,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          "View >",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      "Status >",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F2E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 14,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                deliveryStatus,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      "Processing >",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings,
                              size: 14,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                processingStatus,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Fixed FilterBar class outside of the main PageState (unchanged)
class FilterBar extends StatelessWidget {
  final List<String> processingOptions;
  final List<String> deliveryOptions;
  final String processingFilter;
  final String deliveryFilter;
  final Function(String) onProcessingChanged;
  final Function(String) onDeliveryChanged;

  const FilterBar({
    super.key,
    required this.processingOptions,
    required this.deliveryOptions,
    required this.processingFilter,
    required this.deliveryFilter,
    required this.onProcessingChanged,
    required this.onDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: processingFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Processing',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: processingOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => onProcessingChanged(v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: deliveryFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Delivery',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: deliveryOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => onDeliveryChanged(v!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
