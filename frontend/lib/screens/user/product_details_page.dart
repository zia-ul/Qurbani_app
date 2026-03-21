import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/screens/user/receipt_generator.dart';
import 'package:Qurbani/screens/user/special_request.dart';
import 'package:Qurbani/screens/user/rate_order.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class ProductDetailsPage extends StatefulWidget {
  final String orderId;
  final String userId;

  const ProductDetailsPage({
    super.key,
    required this.orderId,
    required this.userId,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _orderData = await OrderService.getOrderDetails(widget.orderId);

      print("checking particular order details $_orderData");
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String shortenOrderId(dynamic id, {int length = 10}) {
    final value = id.toString();
    if (value.length <= length) return value;
    return value.substring(0, length);
  }

  String lastDigits(String value, {int length = 12}) {
    if (value.length <= length) return value;
    return value.substring(value.length - length);
  }

  int parseStatus(dynamic status) {
    return int.tryParse(status?.toString() ?? '') ?? 0;
  }

  String mapCombinedStatus(dynamic status) {
    final intStatus = parseStatus(status);

    switch (intStatus) {
      case 0:
        return "Not started";
      case 1:
        return "Qurbani Started";
      case 2:
        return "Processing";
      case 3:
        return "Meat Packaged";
      case 4:
        return "Sent for delivery";
      case 5:
        return "Delivered";
      case 6:
        return "Cancelled";
      default:
        return "Unknown";
    }
  }

  String mapPaymentStatus(dynamic status) {
    final intStatus = int.tryParse(status?.toString() ?? '') ?? 2;

    switch (intStatus) {
      case 0:
        return "Paid";
      case 1:
        return "Unpaid";
      case 2:
      default:
        return "Pending";
    }
  }

  String formatQurbaniDay(dynamic value) {
    switch (value?.toString()) {
      case 'day_1':
      case 'Day 1':
        return 'Day 1';
      case 'day_2':
      case 'Day 2':
        return 'Day 2';
      case 'day_3':
      case 'Day 3':
        return 'Day 3';
      default:
        return 'Not set';
    }
  }

  String formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return "Pending";

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  List<String> parsePhotoUrls(dynamic photoUrlsRaw) {
    List<String> photoUrls = [];

    if (photoUrlsRaw is List) {
      photoUrls = photoUrlsRaw.cast<String>();
    } else if (photoUrlsRaw is String) {
      try {
        final decoded = jsonDecode(photoUrlsRaw);
        if (decoded is List) {
          photoUrls = decoded.cast<String>();
        } else if (photoUrlsRaw.startsWith('http')) {
          photoUrls = [photoUrlsRaw];
        }
      } catch (_) {
        if (photoUrlsRaw.startsWith('http')) {
          photoUrls = [photoUrlsRaw];
        }
      }
    }

    return photoUrls;
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
      case 2:
        return Colors.orange;
      case 3:
        return Colors.deepOrange;
      case 4:
        return Colors.blue;
      case 5:
        return Colors.green;
      case 6:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _paymentColor(String payment) {
    switch (payment.toLowerCase()) {
      case "paid":
        return Colors.green;
      case "unpaid":
        return Colors.red;
      case "pending":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelOrder(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Cancel Order"),
        content: const Text(
          "Are you sure you want to cancel? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: AppTheme.warningRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await OrderService.cancelOrder(widget.orderId);
      ToastUtils.showSuccess("Order Cancelled Successfully");
      Navigator.pop(context);
    } catch (e) {
      ToastUtils.showError("Error: $e");
    }
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
    EdgeInsets margin = const EdgeInsets.only(bottom: 16),
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isCopyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ToastUtils.showSuccess("Copied!");
              },
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  int _statusToCode(String status) {
    switch (status.toLowerCase().trim()) {
      case 'not started':
        return 0;
      case 'qurbani started':
        return 1;
      case 'processing':
        return 2;
      case 'meat packaged':
        return 3;
      case 'sent for delivery':
        return 4;
      case 'delivered':
        return 5;
      case 'cancelled':
        return 6;
      default:
        return 0;
    }
  }

  Widget _buildHeroCard(Map<String, dynamic> order, DateTime? orderDate) {
    // final status = mapCombinedStatus(order['status']);
    final payment =
        order['payment_status_label']?.toString() ??
        mapPaymentStatus(order['payment_status']);
    // final statusColor = _statusColor(parseStatus(order['status']));
    final status = order['processing_status']?.toString() ?? 'Unknown';
    final statusColor = _statusColor(_statusToCode(status));
    final paymentColor = _paymentColor(payment);
    print("order sttaus check: $status");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Qurbani Order",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "#${shortenOrderId(order['id'])}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  payment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  "Status",
                  status,
                  statusColor.withOpacity(0.95),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  "Payment",
                  payment,
                  paymentColor.withOpacity(0.95),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  "Ordered",
                  orderDate != null
                      ? DateFormat('dd MMM').format(orderDate)
                      : '--',
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final type = animal['animal_type']?.toString() ?? 'N/A';
    final barcode = animal['barcode']?.toString() ?? 'N/A';
    final animalId = animal['id']?.toString() ?? 'N/A';
    final qurbaniDay = formatQurbaniDay(animal['qurbani_day']);
    final qurbaniDatetime = formatDateTime(animal['qurbani_datetime']);
    final photoUrls = parsePhotoUrls(animal['photo_urls']);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pets, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              _statusChip(qurbaniDay, AppTheme.primaryGreen),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.tag, "Animal #", animalId),
          _buildInfoRow(
            Icons.qr_code_2_rounded,
            "Barcode",
            lastDigits(barcode),
            isCopyable: true,
          ),
          _buildInfoRow(Icons.access_time_rounded, "Qurbani", qurbaniDatetime),
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final url = photoUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      url,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 92,
                        height: 92,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShareholderCard(Map<String, dynamic> shareholder) {
    final photoUrls = parsePhotoUrls(shareholder['photo_urls']);
    final statusText = mapCombinedStatus(shareholder['status']);
    final paymentText = mapPaymentStatus(shareholder['payment_status']);
    final statusColor = _statusColor(parseStatus(shareholder['status']));
    final paymentColor = _paymentColor(paymentText);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
                child: const Icon(
                  Icons.person_outline,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shareholder['shareholder_name']?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(statusText, statusColor),
              _statusChip(paymentText, paymentColor),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.shield_outlined,
            "Guardian",
            shareholder['guardian_name']?.toString() ?? 'N/A',
          ),
          _buildInfoRow(
            Icons.confirmation_number_outlined,
            "Share #",
            shareholder['share_number']?.toString() ?? 'Not assigned',
          ),
          _buildInfoRow(
            Icons.access_time_rounded,
            "Qurbani",
            formatDateTime(shareholder['qurbani_datetime']),
          ),
          if (photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                photoUrls.first,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 170,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text("Order Details"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          title: const Text("Order Details"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _glassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 54,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Something went wrong",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  _buildActionBtn(
                    label: "Retry",
                    icon: Icons.refresh_rounded,
                    color: AppTheme.primaryGreen,
                    onPressed: _fetchOrderDetails,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final order = _orderData!;
    final orderDate = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final processingStatus =
        order['processing_status']?.toString() ?? 'Unknown';
    final bool isDelivered = processingStatus == 'Delivered';
    final bool isCancelled = processingStatus == 'Cancelled';

    bool canCancel = false;
    if (orderDate != null) {
      canCancel =
          DateTime.now().difference(orderDate).inHours < 24 &&
          !isDelivered &&
          !isCancelled;
    }

    final animals = (order['animals'] as List?) ?? [];
    final shareholders = (order['shareholders'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          "Order Details",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrderDetails,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeroCard(order, orderDate),

            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Order Info", Icons.receipt_long_rounded),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.fingerprint_rounded,
                    "Order ID",
                    shortenOrderId(order['id']),
                  ),
                  _buildInfoRow(
                    Icons.info_outline_rounded,
                    "Order Status",
                    order['processing_status']?.toString() ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    Icons.payments_outlined,
                    "Payment",
                    order['payment_status_label']?.toString() ??
                        mapPaymentStatus(order['payment_status']),
                  ),
                  if (orderDate != null)
                    _buildInfoRow(
                      Icons.calendar_today_rounded,
                      "Ordered on",
                      DateFormat('dd MMM yyyy').format(orderDate),
                    ),
                ],
              ),
            ),

            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Admin Details", Icons.verified_user_outlined),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.person_outline_rounded,
                    "Admin",
                    order['admin_name']?.toString() ?? 'Admin',
                  ),
                  _buildInfoRow(
                    Icons.phone_outlined,
                    "Phone",
                    order['admin_phone']?.toString() ?? 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    "Address",
                    order['admin_address']?.toString() ?? 'N/A',
                  ),
                ],
              ),
            ),

            if (animals.isNotEmpty)
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader("Assigned Animals", Icons.pets_outlined),
                    const SizedBox(height: 6),
                    ...animals.map((animal) => _buildAnimalCard(animal)),
                  ],
                ),
              ),

            if (shareholders.isNotEmpty)
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader("Shareholders", Icons.groups_2_outlined),
                    const SizedBox(height: 6),
                    ...shareholders.map((s) => _buildShareholderCard(s)),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    label: "Special Request",
                    icon: Icons.edit_note_rounded,
                    color: AppTheme.primaryGreen,
                    onPressed: (isCancelled || isDelivered)
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SpecialRequestPage(orderData: order),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionBtn(
                    label: "Receipt",
                    icon: Icons.download_rounded,
                    color: Colors.blue.shade700,
                    onPressed: () async {
                      final file = await generateReceiptPDF(_orderData);
                      await OpenFilex.open(file.path);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (isDelivered)
              _buildActionBtn(
                label: "Rate Admin & Delivery",
                icon: Icons.star_rounded,
                color: Colors.orange.shade700,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RateOrderPage(
                      orderId: order['id'].toString(),
                      userId: widget.userId,
                    ),
                  ),
                ),
              ),

            if (canCancel) ...[
              const SizedBox(height: 12),
              _buildActionBtn(
                label: "Cancel Order",
                icon: Icons.cancel_rounded,
                color: AppTheme.warningRed,
                onPressed: () => _cancelOrder(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
