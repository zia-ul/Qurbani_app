import 'package:Qurbani/screens/admin/shareholder_order_details.dart';
import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';

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
  String? _errorMessage;

  final Color lightBg = const Color(0xFFF4F7F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  bool isNewOrder(String createdAt) {
    try {
      final created = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      return now.difference(created).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String shortId(dynamic id, {int length = 8}) {
    final value = (id ?? '').toString();
    if (value.length <= length) return value;
    return value.substring(value.length - length);
  }

  bool _isCodExpired(Map<String, dynamic> order) {
    AppLogger.debug("Checking COD expiry", {
      "orderId": order['orderId'],
      "paymentMethod": order['paymentMethod'],
      "payment_status": order['payment_status'],
      "deadline": order['cod_deadline'],
    });

    final paymentMethod = _asInt(order['paymentMethod']);
    final paymentStatus = _asInt(order['payment_status'], fallback: 2);

    // 0 = Cash
    if (paymentMethod != 0) return false;

    // Auto-cancel if unpaid OR pending
    // 0 = paid, 1 = unpaid, 2 = pending
    if (paymentStatus != 1 && paymentStatus != 2) return false;

    final rawDeadline = order['cod_deadline'];
    if (rawDeadline == null) return false;

    final parsed = DateTime.tryParse(rawDeadline.toString());
    if (parsed == null) return false;

    // If backend sends date-only, treat deadline as end of that day
    final deadline = DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      23,
      59,
      59,
    );

    return DateTime.now().isAfter(deadline);
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await AdminOrderService.getAdminOrders();

      if (!mounted) return;
      setState(() {
        _allOrders = orders;
      });
      AppLogger.info("Orders fetched: ${_allOrders.length}");
    } catch (e, stack) {
      AppLogger.error("Failed to fetch admin orders", e, stack);
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyErrorMessage(
          e,
          fallback: 'Unable to load orders right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  bool _isCancelledOrder(Map<String, dynamic> order) {
    final orderStatus = _asInt(order['orderStatus']);
    final processingStatus =
        order['processing_status']?.toString().trim().toLowerCase() ?? '';

    return orderStatus == 2 ||
        processingStatus == 'cancelled' ||
        _isCodExpired(order);
  }

  bool _isCompletedOrder(Map<String, dynamic> order) {
    if (_isCancelledOrder(order)) return false;

    final orderStatus = _asInt(order['orderStatus']);
    final processingStatus = _getOverallShareholderStatusLabel(
      order,
    ).trim().toLowerCase();

    return orderStatus == 1 || processingStatus == 'delivered';
  }

  int _countOrdersForTab(bool? isActive) {
    return _allOrders.where((order) {
      if (isActive == true) {
        return !_isCompletedOrder(order) && !_isCancelledOrder(order);
      }
      if (isActive == false) {
        return _isCompletedOrder(order);
      }
      return _isCancelledOrder(order);
    }).length;
  }

  String _emptyStateMessage(bool? isActive) {
    if (_searchQuery.isNotEmpty) {
      return 'No matching orders found.';
    }

    if (isActive == true) {
      return 'No active orders right now.';
    }

    if (isActive == false) {
      return 'No completed orders yet.';
    }

    return 'No cancelled orders found.';
  }

  String _getOverallShareholderStatusLabel(Map<String, dynamic> order) {
    final backendStatus = order['processing_status']?.toString();
    if (backendStatus != null && backendStatus.isNotEmpty) {
      return backendStatus;
    }

    final List shareholders = order['shareholders'] ?? [];
    if (shareholders.isEmpty) return 'Not started';

    final statuses = shareholders.map((s) => _asInt(s['status'])).toList();
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

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "$label: $value",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList({required bool? isActive}) {
    final filteredOrders = _allOrders.where((order) {
      bool matchesStatus;
      if (isActive == true) {
        matchesStatus = !_isCompletedOrder(order) && !_isCancelledOrder(order);
      } else if (isActive == false) {
        matchesStatus = _isCompletedOrder(order);
      } else {
        matchesStatus = _isCancelledOrder(order);
      }

      final orderId = (order['orderId'] ?? '').toString().toLowerCase();
      final shareholderNames = ((order['shareholders'] ?? []) as List)
          .map((s) => (s['shareholder_name'] ?? '').toString().toLowerCase())
          .join(' ');
      final guardianNames = ((order['shareholders'] ?? []) as List)
          .map((s) => (s['guardian_name'] ?? '').toString().toLowerCase())
          .join(' ');

      final matchesSearch =
          orderId.contains(_searchQuery) ||
          shareholderNames.contains(_searchQuery) ||
          guardianNames.contains(_searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(child: Text(_emptyStateMessage(isActive)));
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final data = filteredOrders[index];
          final dynamic orderId = data['orderId'];
          final createdAt = data['createdAt'];

          final bool showNew =
              createdAt != null && isNewOrder(createdAt.toString());

          final orderStatusLabel = _getOrderStatusLabel(data);
          final shareholderStatusLabel = _getOverallShareholderStatusLabel(
            data,
          );
          final paymentStatusLabel = (data['payment_status_label'] ?? 'Pending')
              .toString();
          final paymentMethodLabel = (data['paymentMethodLabel'] ?? 'Unknown')
              .toString();
          final totalShares = (data['totalShares'] ?? 0).toString();

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareholderOrderDetails(orderId: orderId),
                ),
              );
              _fetchOrders();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgGradientEnd,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
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
                                        text: "Order #",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: shortId(orderId),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (showNew) newBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              shareholderStatusLabel,
                            ).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            shareholderStatusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(shareholderStatusLabel),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryChip(
                            icon: Icons.payments_outlined,
                            label: "Payment",
                            value: paymentStatusLabel,
                            color: paymentStatusLabel.toLowerCase() == 'paid'
                                ? Colors.green
                                : paymentStatusLabel.toLowerCase() == 'unpaid'
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryChip(
                            icon: Icons.receipt_long_outlined,
                            label: "Method",
                            value: paymentMethodLabel,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryChip(
                            icon: Icons.check_circle_outline,
                            label: "Order",
                            value: orderStatusLabel,
                            color: _getStatusColor(orderStatusLabel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryChip(
                            icon: Icons.groups_2_outlined,
                            label: "Shares",
                            value: totalShares,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "View details",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
        decoration: InputDecoration(
          hintText: "Search ID or shareholder...",
          prefixIcon: const Icon(Icons.search_rounded),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      ('Active', _countOrdersForTab(true)),
      ('Completed', _countOrdersForTab(false)),
      ('Cancelled', _countOrdersForTab(null)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _buildTabSegment(
                    label: tabs[index].$1,
                    count: tabs[index].$2,
                    index: index,
                    isCompact: isCompact,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabSegment({
    required String label,
    required int count,
    required int index,
    required bool isCompact,
  }) {
    final isSelected = _tabController.index == index;
    final foreground = isSelected ? Colors.white : Colors.black87;
    final muted = isSelected ? Colors.white70 : Colors.black54;

    return Padding(
      padding: EdgeInsets.only(right: index == 2 ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _tabController.animateTo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryGreen.withOpacity(0.08),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: isCompact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count.toString(),
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.18)
                                : AppTheme.primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        title: const Text(
          "Orders",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabs(),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: AppTheme.bgGradientEnd,
                            ),
                            child: const Text("Try Again"),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(isActive: true),
                      _buildOrderList(isActive: false),
                      _buildOrderList(isActive: null),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
