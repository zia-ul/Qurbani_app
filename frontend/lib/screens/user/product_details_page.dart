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

  final Color bgParchment = const Color(0xffF2E8D5);

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
      // print(_orderData);
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

  String shortenOrderId(String id, {int length = 10}) {
    if (id.length <= length) return id;
    return id.substring(0, length);
  }

  String lastDigits(String value, {int length = 12}) {
    if (value.length <= length) return value;
    return value.substring(value.length - length);
  }

  Future<void> _cancelOrder(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD1C4A9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1F9).withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16.0), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800], fontSize: 13),
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ToastUtils.showSuccess("ID Copied!");
              },
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
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
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.bgGradientEnd,
          disabledBackgroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgParchment,
        appBar: AppBar(
          title: const Text("Order Details"),
          backgroundColor: AppTheme.bgGradientEnd,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: bgParchment,
        appBar: AppBar(
          title: const Text("Order Details"),
          backgroundColor: AppTheme.bgGradientEnd,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_errorMessage'),
              ElevatedButton(
                onPressed: _fetchOrderDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _orderData!;
    final deliveryStatus = (order['delivery_status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final orderDate = DateTime.tryParse(order['created_at'] ?? '');
    final bool isDelivered = deliveryStatus == 'delivered';
    final bool isCancelled = deliveryStatus == 'cancelled';

    bool canCancel = false;
    if (orderDate != null) {
      canCancel =
          DateTime.now().difference(orderDate).inHours < 24 &&
          !isDelivered &&
          !isCancelled;
    }

    return Scaffold(
      backgroundColor: bgParchment,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Product Info Card
            // Animals Card
            // Animals Card
            if (order['animals'] != null &&
                (order['animals'] as List).isNotEmpty)
              _buildSectionCard(
                title: "Animals",
                icon: Icons.celebration,
                child: Column(
                  children: (order['animals'] as List<dynamic>).map((animal) {
                    // Handle optional fields safely
                    final breed = animal['breed'] ?? 'N/A';
                    final type = animal['animal_type'] ?? 'N/A';
                    final price = animal['price']?.toString() ?? 'N/A';
                    final age = animal['age']?.toString() ?? 'N/A';
                    // final weight =
                    //     animal['details_weight']?.toString() ?? 'N/A';
                    final barcode = animal['barcode'] ?? 'N/A';
                    final qurbani_datetime =
                        animal['qurbani_datetime'] ?? 'N/A';
                    final photoUrlsRaw = animal['photo_urls'];
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

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$type - $breed",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("Price: $price"),
                          Text("Age: $age"),
                          // Text("Weight: $weight"),
                          Row(
                            children: [
                              Expanded(
                                child: Text("Barcode: ${lastDigits(barcode)}"),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: barcode),
                                  );
                                  ToastUtils.showSuccess("Barcode copied!");
                                },
                              ),
                            ],
                          ),

                          Text("Qurbani Time: $qurbani_datetime"),
                          if (photoUrls.isNotEmpty)
                            SizedBox(
                              height: 80,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: photoUrls.map((url) {
                                  return Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const Divider(),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Admin Details Card
            _buildSectionCard(
              title: "Admin Details",
              icon: Icons.account_circle,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   order['admin_name'] ?? 'Admin',
                        //   style: const TextStyle(fontWeight: FontWeight.bold),
                        // ),
                        // Text(
                        //   order['admin_phone'] ?? '+91 9876543210',
                        //   style: const TextStyle(fontSize: 12),
                        // ),
                        // Text(
                        //   order['admin_address'] ?? 'Address',
                        //   style: const TextStyle(
                        //     fontSize: 12,
                        //     color: Colors.grey,
                        //   ),
                        // ),
                        Text(order['admin_name'] ?? 'Admin'),
                        Text(order['admin_phone'] ?? 'N/A'),
                        Text(order['admin_address'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Order Info Card
            _buildSectionCard(
              title: "Order Info",
              icon: Icons.assignment,
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.fingerprint,
                    "Order ID",
                    shortenOrderId(order['id']),
                    isCopyable: false,
                  ),

                  _buildInfoRow(
                    Icons.check_circle,
                    "Payment Status",
                    order['payment_status'],
                  ),

                  _buildInfoRow(
                    Icons.timer,
                    "Processing Status",
                    order['processing_status'] ?? 'pending',
                  ),

                  _buildInfoRow(
                    Icons.local_shipping,
                    "Delivery Status",
                    deliveryStatus,
                  ),

                  _buildInfoRow(
                    Icons.security,
                    "Delivery Code",
                    order['delivery_code'] ?? 'Not assigned',
                    isCopyable: order['delivery_code'] != null,
                  ),
                  if (orderDate != null)
                    _buildInfoRow(
                      Icons.calendar_today,
                      "Ordered on",
                      DateFormat('dd MMMM yyyy').format(orderDate),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Functional Buttons Row
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    label: "Special Request",
                    icon: Icons.edit_note,
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
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionBtn(
                    label: "Download Receipt",
                    icon: Icons.download,
                    color: Colors.blue[700]!,
                    onPressed: () async {
                      final file = await generateReceiptPDF(_orderData);
                      await OpenFilex.open(file.path);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Rate and Cancel Buttons
            if (isDelivered)
              _buildActionBtn(
                label: "Rate Admin & Delivery",
                icon: Icons.star,
                color: Colors.orange[800]!,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RateOrderPage(
                      orderId: order['id'],
                      userId: widget.userId,
                    ),
                  ),
                ),
              ),

            if (canCancel)
              _buildActionBtn(
                label: "Cancel Order",
                icon: Icons.cancel,
                color: AppTheme.warningRed,
                onPressed: () => _cancelOrder(context),
              ),
          ],
        ),
      ),
    );
  }
}
