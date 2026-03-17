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
  final String orderId;

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
  final Map<String, TimeOfDay> _tempScheduleTime = {};

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    fetchAnimals();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _paymentLabel(int status) {
    switch (status) {
      case 0:
        return "Pending";
      case 1:
        return "Paid";
      case 2:
        return "Unpaid";
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

  String formatAddress(String? rawAddress) {
    if (rawAddress == null || rawAddress.isEmpty) return "N/A";

    try {
      final decoded = jsonDecode(rawAddress);

      final country = decoded['country'] ?? '';
      final state = decoded['state'] ?? '';
      final city = decoded['city'] ?? '';
      final addressLine =
          decoded['address_line'] ?? decoded['street'] ?? '';

      return [addressLine, city, state, country]
          .where((e) => e.toString().isNotEmpty)
          .join(', ');
    } catch (_) {
      return rawAddress;
    }
  }

  Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
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
          uniqueAnimals[animal['id'].toString()] =
              Map<String, dynamic>.from(animal);
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

  Future<void> _updateShareholderPayment(String shareholderId, int status) async {
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

  Future<void> _assignScheduleToShareholder(
    String shareholderId,
    TimeOfDay time,
  ) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      final response = await http.post(
        Uri.parse("$_baseUrl/shareholders/$shareholderId/schedule"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"qurbani_datetime": dt.toIso8601String()}),
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Time scheduled successfully");
        await _fetchOrderDetails();
      } else {
        ToastUtils.showError("Failed to schedule time");
      }
    } catch (_) {
      ToastUtils.showError("Something went wrong");
    }
  }

  Future<void> _updateShareholderStatus(String shareholderId, int status) async {
    final token = await _storage.read(key: 'token');

    final response = await http.post(
      Uri.parse("$_baseUrl/shareholders/$shareholderId/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode == 200) {
      ToastUtils.showSuccess("Status updated");
      await _fetchOrderDetails();
    } else {
      ToastUtils.showError("Failed to update status");
    }
  }

  Widget _cardTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );

  Widget _infoRow(String k, String? v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text('$k:')),
            Expanded(child: Text(v ?? 'N/A')),
          ],
        ),
      );

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
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
              : const SizedBox(),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _orderDetailsCard(Map<String, dynamic> data) {
    final double total = double.tryParse(data['total_amt'].toString()) ?? 0.0;

    final formattedAmount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(total);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Order Information'),
            const SizedBox(height: 12),
            _infoRow('Order ID', widget.orderId),
            _infoRow('User', data['user_name']?.toString()),
            _infoRow('Address', data['address']?.toString()),
            _infoRow('Price', formattedAmount),
            _infoRow('Payment', data['payment_status_label']?.toString()),
            _infoRow('Contact', data['contact_no']?.toString()),
          ],
        ),
      ),
    );
  }

  Widget _shareholderFlowCard(Map<String, dynamic> shareholder) {
    final shareholderId = shareholder['id'].toString();

    final paymentStatus = _asInt(shareholder['payment_status']);
    final workflowStatus = _asInt(shareholder['status']);
    final animalId = shareholder['animal_id'];
    final hasAnimal = animalId != null;
    final shareNumber = shareholder['share_number'];
    final schedule = shareholder['qurbani_datetime'] != null
        ? DateTime.tryParse(shareholder['qurbani_datetime'].toString())
        : null;

    final isPaid = paymentStatus == 1;
    final isPaymentDone = isPaid;
    final isAnimalDone = hasAnimal;
    final isScheduleDone = schedule != null;
    final isQurbaniStarted = workflowStatus >= 1;
    final isPackaged = workflowStatus >= 3;
    final isSent = workflowStatus >= 4;
    final isDelivered = workflowStatus >= 5;
    final isCancelled = workflowStatus == 6;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Shareholder: ${shareholder['shareholder_name']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                _statusChip(_paymentLabel(paymentStatus), isPaid ? Colors.green : Colors.orange),
                _statusChip(_statusLabel(workflowStatus), _statusColor(workflowStatus)),
                if (shareNumber != null)
                  _statusChip("Share #$shareNumber", Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatAddress(shareholder['address']?.toString()),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
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
              title: "Schedule Time",
              completed: isScheduleDone,
              active: isAnimalDone && !isScheduleDone,
            ),
            const SizedBox(height: 8),
            _stepTile(
              title: "Qurbani Started",
              completed: isQurbaniStarted,
              active: isScheduleDone && workflowStatus == 0,
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

            if (isCancelled)
              _statusChip("Cancelled", Colors.red),

            if (!isCancelled && !isPaymentDone) ...[
              DropdownButtonFormField<int>(
                value: _tempPaymentStatus[shareholderId] ?? 2,
                decoration: const InputDecoration(
                  labelText: 'Payment Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Unpaid')),
                  DropdownMenuItem(value: 1, child: Text('Paid')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _tempPaymentStatus[shareholderId] = value);
                },
              ),
              const SizedBox(height: 12),
              _primaryButton("Save Payment", () async {
                final selected = _tempPaymentStatus[shareholderId] ?? 2;
                if (selected != 1) {
                  ToastUtils.showError("Please mark payment as Paid");
                  return;
                }
                await _updateShareholderPayment(shareholderId, selected);
                _tempPaymentStatus.remove(shareholderId);
              }),
              const SizedBox(height: 16),
            ],

            if (!isCancelled && isPaymentDone && !isAnimalDone) ...[
              DropdownButtonFormField<String>(
                value: _tempAnimalId[shareholderId],
                decoration: const InputDecoration(
                  labelText: 'Select Animal',
                  border: OutlineInputBorder(),
                ),
                items: availableAnimals.map((animal) {
                  return DropdownMenuItem<String>(
                    value: animal['id'].toString(),
                    child: Text(
                      "${animal['animal_type']} (ID ${animal['id']})",
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
                  decoration: const InputDecoration(
                    labelText: 'Select Share Number',
                    border: OutlineInputBorder(),
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
              }),
              const SizedBox(height: 16),
            ],

            if (!isCancelled && isPaymentDone && isAnimalDone && !isScheduleDone) ...[
              _primaryButton("Pick Qurbani Time", () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                setState(() => _tempScheduleTime[shareholderId] = time);
              }),
              if (_tempScheduleTime[shareholderId] != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Selected Time: ${_tempScheduleTime[shareholderId]!.format(context)}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _primaryButton("Save Schedule", () async {
                  final selectedTime = _tempScheduleTime[shareholderId];
                  if (selectedTime == null) {
                    ToastUtils.showError("Please select a time");
                    return;
                  }
                  await _assignScheduleToShareholder(
                    shareholderId,
                    selectedTime,
                  );
                  _tempScheduleTime.remove(shareholderId);
                }),
              ],
              const SizedBox(height: 16),
            ],

            if (!isCancelled && isScheduleDone && workflowStatus == 0) ...[
              _primaryButton("Mark Qurbani Started", () async {
                await _updateShareholderStatus(shareholderId, 1);
              }),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && (workflowStatus == 1 || workflowStatus == 2)) ...[
              _primaryButton("Mark Meat Packaged", () async {
                await _updateShareholderStatus(shareholderId, 3);
              }),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && workflowStatus == 3) ...[
              _primaryButton("Mark Sent for Delivery", () async {
                await _updateShareholderStatus(shareholderId, 4);
              }),
              const SizedBox(height: 12),
            ],

            if (!isCancelled && workflowStatus == 4) ...[
              _primaryButton("Mark Delivered", () async {
                await _updateShareholderStatus(shareholderId, 5);
              }),
              const SizedBox(height: 12),
            ],

            if (schedule != null) ...[
              const SizedBox(height: 8),
              Text(
                "Scheduled Time: ${DateFormat('hh:mm a').format(schedule.toLocal())}",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = orderData!;
    final List shareholders = data['shareholders'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _orderDetailsCard(data),
          const SizedBox(height: 16),
          ...shareholders.map((s) => _shareholderFlowCard(s)),
        ],
      ),
    );
  }
}