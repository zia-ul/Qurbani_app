import 'package:Qurbani/services/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/services/user_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:provider/provider.dart';

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

  /// ID of the delivery person assigned to this order.
  // String deliveryPersonId = '';

  // /// Name of the delivery person assigned to this order.
  // String deliveryPersonName = '';

  // /// Phone number of the delivery person assigned to this order.
  // String deliveryPersonPhone = '';

  /// Initializes the state of the widget by fetching order details and delivery boys list.
  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchDeliveryBoys();
  }

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
      // print("issue occured $e");
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
      // print(e);
      ToastUtils.showError(e.toString());
    }
  }

  /// Marks a Cash on Delivery order as paid on the server.
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

      // 🔥 fetch delivery boy details explicitly
      // final deliveryBoy = await AdminOrderService.getDeliveryBoyDetails(
      //   widget.orderId,
      //   selectedDeliveryBoyId!,
      // );
      // // print(deliveryBoy);
      // setState(() {
      //   deliveryPersonId = deliveryBoy['id'] ?? '';
      //   deliveryPersonName = deliveryBoy['name'] ?? '';
      //   deliveryPersonPhone = deliveryBoy['phone'] ?? '';
      // });

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
    final currencyNotifier = context.watch<CurrencyNotifier>();

    if (isLoading || !currencyNotifier.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = orderData!;
    // print("order details......$data");
    final List shareholders = data['shareholders'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _orderDetailsCard(data, currencyNotifier),
          if (shareholders.isNotEmpty) ...[
            const SizedBox(height: 16),
            _shareholdersCard(shareholders),
          ],
          const SizedBox(height: 16),

          _processingTimeline(),
          const SizedBox(height: 16),

          if (processing == 'pending') _pendingCard(),
          if (processing == 'confirmed') _confirmedCard(),
          if (processing == 'completed') _deliveryCard(),
        ],
      ),
    );
  }

  // -------------------- CARDS --------------------

  /// Builds a card displaying the main order information, including user details, price, payment status, and a button to mark as paid if applicable.
  Widget _orderDetailsCard(
    Map<String, dynamic> data,
    CurrencyNotifier currencyNotifier,
  ) {
    final double baseTotal =
        double.tryParse(data['total_amount'].toString()) ?? 0.0;

    final double convertedTotal = currencyNotifier.convert(baseTotal);

    final String currencyCode = currencyNotifier.currency;

    // print("...pay....m...${data['paymentMethod']}");
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
            _infoRow(
              'Price',
              '$currencyCode ${convertedTotal.toStringAsFixed(2)}',
            ),

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
                          'Are you sure you want to mark this Cash on Delivery order as paid?',
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

  /// Builds a timeline widget showing the current processing status of the order with visual indicators for pending, confirmed, and completed stages.
  Widget _processingTimeline() {
    final isPending = processing == 'pending';
    final isConfirmed = processing == 'confirmed';
    final isCompleted = processing == 'completed';

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stepDot('Pending', true),
            _divider(),
            _stepDot('Confirmed', isConfirmed || isCompleted),
            _divider(),
            _stepDot('Done', isCompleted),
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

  Widget _stepDot(String label, bool active) => Column(
    children: [
      CircleAvatar(
        radius: 10,
        backgroundColor: active ? AppTheme.primaryGreen : Colors.grey.shade300,
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _divider() =>
      Expanded(child: Container(height: 2, color: Colors.grey.shade300));

  Widget _saveButton(VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(onPressed: onTap, child: const Text('Save')),
  );
}
