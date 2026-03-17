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
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;

  final Color lightBg = const Color(0xFFF4F7F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  int _asInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String shortId(dynamic id, {int length = 8}) {
    final value = id.toString();
    if (value.length <= length) return value;
    return value.substring(value.length - length);
  }

  bool _isCodExpired(Map<String, dynamic> order) {
    AppLogger.debug("Checking COD expiry", {
      "orderId": order['orderId'],
      "paymentMethod": order['paymentMethod'],
      "orderPaymentStatus": order['orderPaymentStatus'],
      "deadline": order['cod_deadline'],
    });

    final paymentMethod = _asInt(order['paymentMethod']);
    final paymentStatus = _asInt(order['orderPaymentStatus'], fallback: 2);

    if (paymentMethod != 0) return false; // 0 = Cash
    if (paymentStatus != 1) return false; // 1 = Unpaid
    if (order['cod_deadline'] == null) return false;

    final deadline = DateTime.tryParse(order['cod_deadline'].toString());
    if (deadline == null) return false;

    return DateTime.now().isAfter(deadline);
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      _allOrders = await AdminOrderService.getAdminOrders();
      AppLogger.info("Orders fetched: ${_allOrders.length}");

      for (final order in _allOrders) {
        final isExpired = _isCodExpired(order);
        final isAlreadyCancelled = _asInt(order['orderStatus']) == 2;

        if (isExpired && !isAlreadyCancelled) {
          AppLogger.warning(
            "Auto-cancelling expired COD order: ${order['orderId']}",
          );
          await AdminOrderService.cancelOrder(order['orderId']);
        }
      }

      _allOrders = await AdminOrderService.getAdminOrders();
      AppLogger.info("Orders reloaded after cancellation cleanup");
    } catch (e, stack) {
      AppLogger.error("Failed to fetch admin orders", e, stack);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getOverallShareholderStatusLabel(Map<String, dynamic> order) {
    final List shareholders = order['shareholders'] ?? [];
    if (shareholders.isEmpty) return 'Not started';

    final statuses = shareholders
        .map((s) => _asInt(s['status']))
        .toList();

    final maxStatus = statuses.reduce((a, b) => a > b ? a : b);

    switch (maxStatus) {
      case 0:
        return 'Not started';
      case 1:
        return 'Qurbani Started';
      case 2:
        return 'Processing';
      case 3:
        return 'Meat Packaged';
      case 4:
        return 'Sent for delivery';
      case 5:
        return 'Delivered';
      case 6:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _getOrderStatusLabel(Map<String, dynamic> order) {
    if (_isCodExpired(order)) return 'Cancelled';
    return (order['orderStatusLabel'] ?? 'Active').toString();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return AppTheme.warningRed;
      case 'sent for delivery':
        return Colors.blue;
      case 'processing':
      case 'qurbani started':
      case 'meat packaged':
        return Colors.orange;
      case 'active':
      case 'not started':
      default:
        return AppTheme.primaryGreen;
    }
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

  Widget _buildOrderList({required bool? isActive}) {
    final filteredOrders = _allOrders.where((order) {
      final orderStatus = _asInt(order['orderStatus']);
      final shareholderStatusLabel = _getOverallShareholderStatusLabel(order);

      final isCancelled = orderStatus == 2 || _isCodExpired(order);
      final isCompleted =
          orderStatus == 1 ||
          shareholderStatusLabel.toLowerCase() == 'delivered';

      bool matchesStatus;
      if (isActive == true) {
        matchesStatus = !isCompleted && !isCancelled;
      } else if (isActive == false) {
        matchesStatus = isCompleted && !isCancelled;
      } else {
        matchesStatus = isCancelled;
      }

      final orderId = (order['orderId'] ?? '').toString().toLowerCase();
      final phone =
          (order['contact'] is Map
                  ? order['contact']['primary']
                  : order['contact'] ?? '')
              .toString()
              .toLowerCase();

      final matchesSearch =
          orderId.contains(_searchQuery) || phone.contains(_searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredOrders.isEmpty) {
      return const Center(child: Text("No orders found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final data = filteredOrders[index];
        final dynamic orderId = data['orderId'];
        final createdAt = data['createdAt'];

        final bool showNew =
            createdAt != null && isNewOrder(createdAt.toString());

        final orderStatusLabel = _getOrderStatusLabel(data);
        final shareholderStatusLabel = _getOverallShareholderStatusLabel(data);
        final paymentStatusLabel =
            (data['orderPaymentStatusLabel'] ?? 'Pending').toString();
        final paymentMethodLabel =
            (data['paymentMethodLabel'] ?? 'Unknown').toString();

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
                            builder: (_) => ShareholderOrderDetails(
                              orderId: orderId.toString(),
                            ),
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
                      "Order >",
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
                              Icons.assignment_outlined,
                              size: 14,
                              color: _getStatusColor(orderStatusLabel),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                orderStatusLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _getStatusColor(orderStatusLabel),
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
                      "Progress >",
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
                              color: _getStatusColor(shareholderStatusLabel),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                shareholderStatusLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _getStatusColor(shareholderStatusLabel),
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
                      "Payment >",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "$paymentStatusLabel ($paymentMethodLabel)",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                Tab(text: "Cancelled"),
              ],
            ),
          ),
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
                        _buildOrderList(isActive: null),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

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