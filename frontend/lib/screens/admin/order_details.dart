import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/services/user_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  /// Holds the detailed data of the order fetched from the server, including user info, payment status, etc.
  Map<String, dynamic>? orderData;

  /// Indicates whether the order details are currently being loaded from the server.
  bool isLoading = true;

  /// Represents the current processing status of the order (e.g., 'pending', 'confirmed', 'completed').
  String processing = 'pending';

  /// Stores the selected date for the Qurbani event.
  DateTime? qurbaniDate;

  /// Stores the selected time for the Qurbani event.
  TimeOfDay? qurbaniTime;

  /// Controller for the text field input of meat weight in kilograms.
  final TextEditingController meatWeightCtrl = TextEditingController();

  /// Controller for the text field input describing body parts distribution.
  final TextEditingController bodyPartsCtrl = TextEditingController();

  /// ID of the selected delivery boy for assignment to this order.
  String? selectedDeliveryBoyId;

  /// List of available delivery boys, each represented as a map with their details (id, name, etc.).
  List<Map<String, dynamic>> deliveryBoys = [];

  /// Indicates whether the list of delivery boys is currently being loaded.
  bool loadingDeliveryBoys = true;
  List<Map<String, dynamic>> availableAnimals = [];
  bool loadingAnimals = true;
  String? selectedAnimalId;
  int? selectedShareNumber;
  Map<String, dynamic>? selectedAnimal;

  /// Initializes the state of the widget by fetching order details and delivery boys list.
  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchDeliveryBoys();
    fetchAnimals();
  }

  // -------- STEP STATE GETTERS --------

  bool get isPaid =>
      orderData != null && orderData!['payment_status'] == 'paid';

  bool get hasAnimal => orderData != null && orderData!['animal_id'] != null;

  bool get hasSchedule =>
      orderData != null && orderData!['qurbani_datetime'] != null;

  bool get hasDelivery =>
      orderData != null && orderData!['delivery_person_id'] != null;

  /// Fetches the detailed information of the order from the server using the order ID.
  Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
      processing = orderData!['processing_status'];

      selectedDeliveryBoyId = orderData!['delivery_person_id']?.toString();
    } catch (e) {
      ToastUtils.showError('Failed to load order: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Fetches the list of available delivery boys from the server.
  Future<void> _fetchDeliveryBoys() async {
    try {
      deliveryBoys = await UserService.getDeliveryBoys();
    } catch (e) {
      ToastUtils.showError('Failed to load delivery boys');
    } finally {
      setState(() => loadingDeliveryBoys = false);
    }
  }

  /// Saves the scheduled date and time for the Qurbani event to the server.
  Future<void> _saveSchedule() async {
    if (qurbaniDate == null || qurbaniTime == null) {
      ToastUtils.showError('Select date & time');
      return;
    }

    final dt = DateTime(
      qurbaniDate!.year,
      qurbaniDate!.month,
      qurbaniDate!.day,
      qurbaniTime!.hour,
      qurbaniTime!.minute,
    );

    try {
      await AdminOrderService.updateSchedule(widget.orderId, dt);
      ToastUtils.showSuccess('Qurbani scheduled');
      _fetchOrderDetails();
    } catch (e) {
      ToastUtils.showError(e.toString());
    }
  }

  /// Saves the meat weight and body parts details for the order to the server.
  Future<void> _saveMeatDetails() async {
    try {
      await AdminOrderService.updateMeatDetails(
        widget.orderId,
        meatWeight: meatWeightCtrl.text,
        bodyPartsDescription: bodyPartsCtrl.text,
      );
      ToastUtils.showSuccess('Meat details saved');
      _fetchOrderDetails();
    } catch (e) {
      ToastUtils.showError(e.toString());
    }
  }

  /// Marks a Cash order as paid on the server.
  Future<void> _markCodAsPaid() async {
    try {
      await AdminOrderService.markCodOrderAsPaid(widget.orderId);

      ToastUtils.showSuccess('Order marked as paid');
      await _fetchOrderDetails();
      setState(() {});
    } catch (e) {
      ToastUtils.showError(e.toString());
    }
  }

  final _storage = const FlutterSecureStorage();
  static final String _baseUrl = dotenv.env['BASE_URL']!;

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

        // 🔥 REMOVE DUPLICATES BY ID
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
    } catch (e) {
      ToastUtils.showError("Something went wrong");
    } finally {
      setState(() => loadingAnimals = false);
    }
  }

  Widget _animalStepCard() {
    if (loadingAnimals) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (availableAnimals.isEmpty) {
      return _actionCard(
        title: 'Step 1: Animal Selection',
        child: const Text('No available animals found'),
      );
    }

    return _actionCard(
      title: 'Step 1: Select Animal Share',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Animal Dropdown
          DropdownButtonFormField<String>(
            value:
                availableAnimals
                        .where(
                          (a) =>
                              a['id'].toString() ==
                              selectedAnimalId?.toString(),
                        )
                        .length ==
                    1
                ? selectedAnimalId
                : null,
            decoration: const InputDecoration(
              labelText: 'Select Animal',
              border: OutlineInputBorder(),
            ),
            items: availableAnimals.map((animal) {
              return DropdownMenuItem<String>(
                value: animal['id'],
                child: Text(
                  "${animal['animal_type']}"
                  "(Remaining: ${animal['remaining_shares'] ?? animal['shares']})",
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedAnimalId = value;
                selectedAnimal = availableAnimals.firstWhere(
                  (a) => a['id'] == value,
                );

                selectedShareNumber = null; // reset share
              });
            },
          ),

          const SizedBox(height: 16),

          /// 🧩 Share Dropdown (only if animal selected)
          if (selectedAnimal != null)
            DropdownButtonFormField<int>(
              value: selectedShareNumber,
              decoration: const InputDecoration(
                labelText: 'Select Share',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                selectedAnimal!['remaining_shares'] ??
                    selectedAnimal!['shares'],
                (index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text("Share ${index + 1}"),
                ),
              ),
              onChanged: (value) {
                setState(() => selectedShareNumber = value);
              },
            ),

          const SizedBox(height: 20),

          /// ✅ Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (selectedAnimalId != null && selectedShareNumber != null)
                  ? () => _assignAnimalShare()
                  : null,
              child: const Text("Assign Share"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignAnimalShare() async {
    if (selectedAnimalId == null || selectedShareNumber == null) {
      ToastUtils.showError("Select animal and share");
      return;
    }

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$_baseUrl/orders/${widget.orderId}/assign-animal"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "animalId": selectedAnimalId,
          "shareNumber": selectedShareNumber,
        }),
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Share assigned successfully");

        await _fetchOrderDetails();
        await fetchAnimals();

        setState(() {
          selectedAnimalId = null;
          selectedShareNumber = null;
          selectedAnimal = null;
        });
      } else {
        ToastUtils.showError("Failed to assign share");
      }
    } catch (e) {
      ToastUtils.showError("Something went wrong");
    }
  }

  /// Assigns a selected delivery boy to the order and updates the delivery person details.
  Future<void> _saveDelivery() async {
    if (selectedDeliveryBoyId == null) {
      ToastUtils.showError('Select delivery boy');
      return;
    }

    try {
      await AdminOrderService.assignDeliveryBoy(
        widget.orderId,
        selectedDeliveryBoyId!,
      );

      ToastUtils.showSuccess('Delivery assigned');
    } catch (e) {
      ToastUtils.showError(e.toString());
    }
  }

  Map<String, dynamic>? get selectedDeliveryBoy {
    if (selectedDeliveryBoyId == null || deliveryBoys.isEmpty) return null;

    try {
      return deliveryBoys.firstWhere(
        (boy) => boy['id'].toString() == selectedDeliveryBoyId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

          /// STEP FLOW CONTROLLED BY BACKEND STATE ONLY

          // STEP 0: Payment
          if (orderData!['payment_status'] != 'paid')
            _paymentStepCard()
          // STEP 1: Animal Assignment
          else if (orderData!['animal_id'] == null)
            _animalStepCard()
          // STEP 2: Schedule (after animal assigned)
          else if (processing == 'pending')
            _pendingCard()
          // STEP 3: Meat Details
          else if (processing == 'confirmed')
            _confirmedCard()
          // STEP 4: Delivery
          else if (processing == 'completed')
            _deliveryCard(),

          const SizedBox(height: 16),

          // Show shareholders ONLY when animal exists
          if (orderData!['animal_id'] != null && shareholders.isNotEmpty) ...[
            _shareholdersCard(shareholders),
          ],
        ],
      ),
    );
  }

  // -------------------- CARDS --------------------

  /// Builds a card displaying the main order information, including user details, price, payment status, and a button to mark as paid if applicable.
  Widget _orderDetailsCard(Map<String, dynamic> data) {
    // final double baseTotal =
    //     double.tryParse(data['total_amount'].toString()) ?? 0.0;

    // final double convertedTotal = currencyNotifier.convert(baseTotal);

    // final String currencyCode = currencyNotifier.currency;
    final double total =
        double.tryParse(data['total_amount'].toString()) ?? 0.0;

    final formattedAmount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(total);

    final bool showMarkAsPaidButton =
        (data['paymentMethod'] ?? '').toString().toLowerCase().trim() ==
            'cash' &&
        data['payment_status'] == 'unpaid';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Order Information'),
            _infoRow('Order ID', widget.orderId),

            _infoRow('User', data['user_name']),
            _infoRow('Address', data['address']),
            _infoRow('Animal Type', data['animal_type']),
            _infoRow('Price', formattedAmount),

            _infoRow('Payment', data['payment_status']),

            if (showMarkAsPaidButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Confirm Payment'),
                        content: const Text(
                          'Are you sure you want to mark this Cash order as paid?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Confirm'),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _markCodAsPaid();
                    }
                  },
                ),
              ),
            ],

            // _infoRow('Address', data['delivery_address']),
            _infoRow('Contact', data['contact_no']),
          ],
        ),
      ),
    );
  }

  Widget _paymentStepCard() {
    final isCash =
        (orderData!['paymentMethod'] ?? '').toString().toLowerCase() == 'cash';

    if (!isCash) return const SizedBox();

    return _actionCard(
      title: 'Step 0: Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order payment is pending. Please confirm payment to continue.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Mark as Paid'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _markCodAsPaid,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card displaying the list of shareholders associated with the order, showing their names, guardians, and Qurbani days.
  Widget _shareholdersCard(List shareholders) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Shareholders'),
            const SizedBox(height: 12),

            ...shareholders.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final s = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shareholder $i',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    _infoRow('Name', s['shareholder_name']),
                    _infoRow('Guardian', s['guardian_name']),
                    _infoRow('Qurbani Day', s['qurbani_day']),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Builds a card for the pending status, allowing the admin to schedule the Qurbani date and time.
  Widget _pendingCard() {
    return _actionCard(
      title: 'Step 1: Schedule Qurbani',
      child: Row(
        children: [
          // Date button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDate: DateTime.now(),
                  );
                  if (d != null) setState(() => qurbaniDate = d);
                },
                child: Text(
                  qurbaniDate == null
                      ? 'Date'
                      : qurbaniDate!.toLocal().toString().split(' ')[0],
                ),
              ),
            ),
          ),

          // Time button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) setState(() => qurbaniTime = t);
                },
                child: Text(
                  qurbaniTime == null ? 'Time' : qurbaniTime!.format(context),
                ),
              ),
            ),
          ),

          // Save button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _saveButton(_saveSchedule),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card for the confirmed status, allowing the admin to input meat weight and body parts details.
  Widget _confirmedCard() {
    return _actionCard(
      title: 'Step 2: Meat Details',
      child: Column(
        children: [
          TextField(
            controller: meatWeightCtrl,
            decoration: const InputDecoration(
              labelText: 'Meat Weight (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // TextField(
          //   controller: bodyPartsCtrl,
          //   maxLines: 3,
          //   decoration: const InputDecoration(
          //     labelText: 'Body Parts Description',
          //     border: OutlineInputBorder(),
          //   ),
          // ),
          // const SizedBox(height: 16),
          _saveButton(_saveMeatDetails),
        ],
      ),
    );
  }

  /// Builds a card for the completed status, showing delivery assignment or allowing assignment if not yet done.
  Widget _deliveryCard() {
    final data = orderData!;
    final bool isAssigned = data['delivery_person_id'] != null;

    if (isAssigned) {
      return _actionCard(
        title: 'Delivery Assigned',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚚 Delivery Boy assigned successfully',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),

            if (selectedDeliveryBoy != null)
              _deliveryBoyProfileCard(selectedDeliveryBoy!),
          ],
        ),
      );
    }

    // fallback: assignment UI
    return _actionCard(
      title: 'Step 3: Assign Delivery',
      child: loadingDeliveryBoys
          ? const LinearProgressIndicator()
          : Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDeliveryBoyId,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Boy',
                    border: OutlineInputBorder(),
                  ),
                  items: deliveryBoys
                      .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem<String>(
                          value: e['id'].toString(),
                          child: Text(e['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedDeliveryBoyId = v),
                ),
                const SizedBox(height: 16),
                _saveButton(_saveDelivery),
              ],
            ),
    );
  }

  /// Builds a profile card for the assigned delivery boy, displaying their name and phone number.
  Widget _deliveryBoyProfileCard(Map<String, dynamic> deliveryBoy) {
    return Card(
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryGreen,
              child: Text(
                deliveryBoy['name']?[0]?.toUpperCase() ?? 'D',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deliveryBoy['name'] ?? 'Delivery Person',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deliveryBoy['phone'] ?? 'Phone not available',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (deliveryBoy['address'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      deliveryBoy['address'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- UI HELPERS --------------------

  Widget _actionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_cardTitle(title), const SizedBox(height: 12), child],
        ),
      ),
    );
  }

  Widget _cardTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _infoRow(String k, String? v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text('$k:')),
        Expanded(child: Text(v ?? 'N/A')),
      ],
    ),
  );

  Widget _saveButton(VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(onPressed: onTap, child: const Text('Save')),
  );
}
