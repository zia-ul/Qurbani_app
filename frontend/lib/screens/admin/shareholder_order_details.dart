import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class ShareholderOrderDetails extends StatefulWidget {
  final dynamic orderId;

  const ShareholderOrderDetails({super.key, required this.orderId});

  @override
  State<ShareholderOrderDetails> createState() =>
      _ShareholderOrderDetailsState();
}

class _ShareholderOrderDetailsState extends State<ShareholderOrderDetails> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;

  List<Map<String, dynamic>> availableAnimals = [];
  bool loadingAnimals = true;

  final _storage = const FlutterSecureStorage();
  static final String _baseUrl = dotenv.env['BASE_URL']!;

  final Map<String, int> _tempPaymentStatus = {};
  final Map<String, String> _tempAnimalId = {};
  final Map<String, int> _tempShareNumber = {};

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    fetchAnimals();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _paymentLabel(int status) {
    switch (status) {
      case 0:
        return "Paid";
      case 1:
        return "Unpaid";
      case 2:
        return "Pending";
      default:
        return "Unknown";
    }
  }

  String _statusLabel(int status) {
    switch (status) {
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

  Color _statusColor(int status) {
    switch (status) {
      case 1:
      case 2:
      case 3:
        return Colors.orange;
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

  Color _paymentColor(int status) {
    switch (status) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String formatAddress(String? rawAddress) {
    if (rawAddress == null || rawAddress.isEmpty) return "N/A";

    try {
      final decoded = jsonDecode(rawAddress);
      final country = decoded['country'] ?? '';
      final state = decoded['state'] ?? '';
      final city = decoded['city'] ?? '';
      final addressLine = decoded['address_line'] ?? decoded['street'] ?? '';

      return [
        addressLine,
        city,
        state,
        country,
      ].where((e) => e.toString().isNotEmpty).join(', ');
    } catch (_) {
      return rawAddress;
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return "N/A";
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  String _formatAmount(dynamic value) {
    final total = _asDouble(value);
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(total);
  }

  Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(
        widget.orderId.toString(),
      );

      print("$orderData");
    } catch (e) {
      ToastUtils.showError('Failed to load order: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> fetchAnimals() async {
    setState(() => loadingAnimals = true);

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse("$_baseUrl/animals"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List rawAnimals = decoded['animals'] ?? [];

        final Map<String, Map<String, dynamic>> uniqueAnimals = {};
        for (var animal in rawAnimals) {
          uniqueAnimals[animal['id'].toString()] = Map<String, dynamic>.from(
            animal,
          );
        }

        setState(() {
          availableAnimals = uniqueAnimals.values.toList();
        });
      } else {
        ToastUtils.showError("Failed to load animals");
      }
    } catch (_) {
      ToastUtils.showError("Something went wrong while loading animals");
    } finally {
      if (mounted) {
        setState(() => loadingAnimals = false);
      }
    }
  }

  Future<void> _updateShareholderPayment(
    String shareholderId,
    int status,
  ) async {
    final token = await _storage.read(key: 'token');

    final response = await http.post(
      Uri.parse("$_baseUrl/shareholders/$shareholderId/payment"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"payment_status": status}),
    );

    if (response.statusCode == 200) {
      ToastUtils.showSuccess("Payment updated successfully");
      await _fetchOrderDetails();
    } else {
      ToastUtils.showError("Failed to update payment");
    }
  }

  Future<void> _assignAnimalToShareholder(
    String shareholderId,
    String animalId,
    int shareNumber,
  ) async {
    final token = await _storage.read(key: 'token');

    final response = await http.post(
      Uri.parse("$_baseUrl/shareholders/$shareholderId/assign-animal"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "animal_id": int.parse(animalId),
        "share_number": shareNumber,
      }),
    );

    if (response.statusCode == 200) {
      ToastUtils.showSuccess("Animal assigned successfully");
      await _fetchOrderDetails();
    } else {
      ToastUtils.showError("Failed to assign animal");
    }
  }

  Future<void> _updateShareholderStatus(
    String shareholderId,
    int status,
  ) async {
    try {
      final token = await _storage.read(key: 'token');

      final response = await http.patch(
        Uri.parse("$_baseUrl/shareholders/$shareholderId/status"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": status}),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ToastUtils.showSuccess(decoded["message"] ?? "Status updated");
        await _fetchOrderDetails();
      } else {
        ToastUtils.showError(decoded["message"] ?? "Failed to update status");
      }
    } catch (_) {
      ToastUtils.showError("Something went wrong");
    }
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _infoRow(String k, String? v, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 110,
            child: Text(
              '$k:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _stepTile({
    required String title,
    required bool completed,
    required bool active,
  }) {
    final color = completed
        ? Colors.green
        : active
        ? AppTheme.primaryGreen
        : Colors.grey.shade400;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: completed
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : active
              ? const Icon(Icons.play_arrow, size: 16, color: Colors.white)
              : const SizedBox(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed, {IconData? icon}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_circle_outline, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _summaryCard(Map<String, dynamic> data) {
    final paymentLabel = _asString(
      data['payment_status_label'],
      fallback: 'Pending',
    );
    final processingLabel = _asString(
      data['processing_status'],
      fallback: 'Not started',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF4B7E52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order #${widget.orderId}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(data['created_at']),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(paymentLabel, Colors.white),
              _statusChip(processingLabel, Colors.white),
              _statusChip(
                _asString(data['payment_method_label'], fallback: 'Unknown'),
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderDetailsCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Order Information', Icons.receipt_long_outlined),
            const SizedBox(height: 14),
            _infoRow(
              'Order ID',
              widget.orderId.toString(),
              icon: Icons.confirmation_number_outlined,
            ),
            _infoRow(
              'User',
              data['user_name']?.toString(),
              icon: Icons.person_outline,
            ),
            _infoRow(
              'Address',
              formatAddress(data['address']?.toString()),
              icon: Icons.location_on_outlined,
            ),
            _infoRow(
              'Price',
              _formatAmount(data['total_amt']),
              icon: Icons.currency_rupee,
            ),
            _infoRow(
              'Payment',
              data['payment_status_label']?.toString(),
              icon: Icons.payments_outlined,
            ),
            _infoRow(
              'Contact',
              data['contact_no']?.toString(),
              icon: Icons.phone_outlined,
            ),
            _infoRow(
              'Order Status',
              data['order_status_label']?.toString() ??
                  data['processing_status']?.toString(),
              icon: Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  String formatQurbaniDay(dynamic value) {
    print("Day: $value");

    final day = value?.toString().trim().toLowerCase();
    print("Day: $day");
    switch (day) {
      case 'day_1':
      case 'day 1':
        return 'Day 1';
      case 'day_2':
      case 'day 2':
        return 'Day 2';
      case 'day_3':
      case 'day 3':
        return 'Day 3';
      default:
        return value?.toString() ?? 'Unknown Day';
    }
  }

  Widget _shareholderFlowCard(Map<String, dynamic> shareholder) {
    final shareholderId = shareholder['id'].toString();

    final paymentStatus = _asInt(shareholder['payment_status'], fallback: 2);
    final workflowStatus = _asInt(shareholder['status']);
    final animalId = shareholder['animal_id'];
    final hasAnimal = animalId != null;
    final shareNumber = shareholder['share_number'];

    final isPaid = paymentStatus == 0;
    final isPaymentDone = isPaid;
    final isAnimalDone = hasAnimal;
    final isQurbaniStarted = workflowStatus >= 1;
    final isPackaged = workflowStatus >= 3;
    final isSent = workflowStatus >= 4;
    final isDelivered = workflowStatus >= 5;
    final isCancelled = workflowStatus == 6;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Shareholder: ${shareholder['shareholder_name']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (shareNumber != null)
                  _statusChip("Share #$shareNumber", Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Guardian: ${shareholder['guardian_name'] ?? 'N/A'}",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(
                  _paymentLabel(paymentStatus),
                  _paymentColor(paymentStatus),
                ),
                _statusChip(
                  _statusLabel(workflowStatus),
                  _statusColor(workflowStatus),
                ),
                if (shareholder['animal_type'] != null)
                  _statusChip(
                    shareholder['animal_type'].toString(),
                    Colors.deepPurple,
                  ),
                if (shareholder['qurbani_day'] != null)
                  _statusChip(
                    formatQurbaniDay(shareholder['qurbani_day']),
                    Colors.teal,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _infoRow(
                    'Address',
                    formatAddress(shareholder['address']?.toString()),
                    icon: Icons.location_on_outlined,
                  ),
                  _infoRow(
                    'Qurbani Time',
                    shareholder['qurbani_datetime'] == null
                        ? 'Pending'
                        : _formatDateTime(shareholder['qurbani_datetime']),
                    icon: Icons.schedule_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _stepTile(
              title: "Payment",
              completed: isPaymentDone,
              active: !isPaymentDone,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Animal Assignment",
              completed: isAnimalDone,
              active: isPaymentDone && !isAnimalDone,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Qurbani Started",
              completed: isQurbaniStarted,
              active: isAnimalDone && workflowStatus == 0,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Meat Packaged",
              completed: isPackaged,
              active: workflowStatus == 1 || workflowStatus == 2,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Sent for Delivery",
              completed: isSent,
              active: workflowStatus == 3,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Delivered",
              completed: isDelivered,
              active: workflowStatus == 4,
            ),

            const Divider(height: 28),

            if (isCancelled) ...[
              _statusChip("Cancelled", Colors.red),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && !isPaymentDone) ...[
              DropdownButtonFormField<int>(
                value: _tempPaymentStatus[shareholderId] ?? 2,
                decoration: InputDecoration(
                  labelText: 'Payment Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Pending')),
                  DropdownMenuItem(value: 1, child: Text('Unpaid')),
                  DropdownMenuItem(value: 0, child: Text('Paid')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _tempPaymentStatus[shareholderId] = value);
                },
              ),
              const SizedBox(height: 12),
              _primaryButton("Save Payment", () async {
                final selected = _tempPaymentStatus[shareholderId] ?? 2;
                await _updateShareholderPayment(shareholderId, selected);
                _tempPaymentStatus.remove(shareholderId);
              }, icon: Icons.payments_outlined),
              const SizedBox(height: 16),
            ],

            if (!isCancelled && isPaymentDone && !isAnimalDone) ...[
              DropdownButtonFormField<String>(
                value: _tempAnimalId[shareholderId],
                decoration: InputDecoration(
                  labelText: 'Select Animal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: availableAnimals.map((animal) {
                  final scheduleText = _formatDateTime(
                    animal['qurbani_datetime'],
                  );

                  final qurbaniDay =
                      animal['qurbani_day']?.toString().replaceAll('_', ' ') ??
                      '';

                  return DropdownMenuItem<String>(
                    value: animal['id'].toString(),
                    child: Text(
                      "${animal['animal_type']} - ${qurbaniDay.toUpperCase()} - $scheduleText",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _tempAnimalId[shareholderId] = value;
                    _tempShareNumber.remove(shareholderId);
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_tempAnimalId[shareholderId] != null)
                DropdownButtonFormField<int>(
                  value: _tempShareNumber[shareholderId],
                  decoration: InputDecoration(
                    labelText: 'Select Share Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: List.generate(7, (index) => index + 1)
                      .map(
                        (share) => DropdownMenuItem<int>(
                          value: share,
                          child: Text("Share $share"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _tempShareNumber[shareholderId] = value);
                  },
                ),
              const SizedBox(height: 12),
              _primaryButton("Save Animal Assignment", () async {
                final animalId = _tempAnimalId[shareholderId];
                final shareNo = _tempShareNumber[shareholderId];

                if (animalId == null || shareNo == null) {
                  ToastUtils.showError("Select animal and share number");
                  return;
                }

                await _assignAnimalToShareholder(
                  shareholderId,
                  animalId,
                  shareNo,
                );

                _tempAnimalId.remove(shareholderId);
                _tempShareNumber.remove(shareholderId);
              }, icon: Icons.pets_outlined),
              const SizedBox(height: 16),
            ],

            if (!isCancelled &&
                isPaymentDone &&
                isAnimalDone &&
                workflowStatus == 0) ...[
              _primaryButton("Mark Qurbani Started", () async {
                await _updateShareholderStatus(shareholderId, 1);
              }, icon: Icons.play_arrow_rounded),
              const SizedBox(height: 12),
            ],

            if (!isCancelled &&
                (workflowStatus == 1 || workflowStatus == 2)) ...[
              _primaryButton("Mark Meat Packaged", () async {
                await _updateShareholderStatus(shareholderId, 3);
              }, icon: Icons.inventory_2_outlined),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && workflowStatus == 3) ...[
              _primaryButton("Mark Sent for Delivery", () async {
                await _updateShareholderStatus(shareholderId, 4);
              }, icon: Icons.local_shipping_outlined),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && workflowStatus == 4) ...[
              _primaryButton("Mark Delivered", () async {
                await _updateShareholderStatus(shareholderId, 5);
              }, icon: Icons.check_circle_outline),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = orderData!;
    final List shareholders = data['shareholders'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _fetchOrderDetails,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrderDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(data),
            const SizedBox(height: 16),
            _orderDetailsCard(data),
            const SizedBox(height: 16),
            _sectionTitle('Shareholder Workflow', Icons.groups_2_outlined),
            const SizedBox(height: 12),
            ...shareholders.map((s) => _shareholderFlowCard(s)),
          ],
        ),
      ),
    );
  }
}
