import 'package:Qurbani/services/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/services/user_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;

  String processing = 'pending';
  DateTime? qurbaniDate;
  TimeOfDay? qurbaniTime;

  final TextEditingController meatWeightCtrl = TextEditingController();
  final TextEditingController bodyPartsCtrl = TextEditingController();

  String? selectedDeliveryBoyId;
  List<Map<String, dynamic>> deliveryBoys = [];
  bool loadingDeliveryBoys = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchDeliveryBoys();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
      processing = orderData!['processing_status'];
      print("RAW STATUS => '$orderData'");
      print("NORMALIZED => '$processing'");
    } catch (e) {
      ToastUtils.showError('Failed to load order: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDeliveryBoys() async {
    try {
      deliveryBoys = await UserService.getDeliveryBoys();
    } catch (e) {
      ToastUtils.showError('Failed to load delivery boys');
    } finally {
      setState(() => loadingDeliveryBoys = false);
    }
  }

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
      print("issue occured $e");
      ToastUtils.showError(e.toString());
    }
  }

  Future<void> _saveMeatDetails() async {
    // if (meatWeightCtrl.text.isEmpty || bodyPartsCtrl.text.isEmpty) {
    //   ToastUtils.showError('Fill all fields');
    //   return;
    // }

    try {
      await AdminOrderService.updateMeatDetails(
        widget.orderId,
        meatWeight: meatWeightCtrl.text,
        bodyPartsDescription: bodyPartsCtrl.text,
      );
      ToastUtils.showSuccess('Meat details saved');
      _fetchOrderDetails();
    } catch (e) {
      print(e);
      ToastUtils.showError(e.toString());
    }
  }

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
      _fetchOrderDetails();
    } catch (e) {
      print(e);
      ToastUtils.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyNotifier = context.watch<CurrencyNotifier>();

    if (isLoading || !currencyNotifier.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = orderData!;
    print("order details......$data");
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

  Widget _orderDetailsCard(
    Map<String, dynamic> data,
    CurrencyNotifier currencyNotifier,
  ) {
    final double baseTotal =
        double.tryParse(data['total_amount'].toString()) ?? 0.0;

    final double convertedTotal = currencyNotifier.convert(baseTotal);

    final String currencyCode = currencyNotifier.currency;

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
            _infoRow('Animal Type', data['animal_type']),
            _infoRow(
              'Price',
              '$currencyCode ${convertedTotal.toStringAsFixed(2)}',
            ),

            _infoRow('Payment', data['payment_status']),
            // _infoRow('Address', data['delivery_address']),
            _infoRow('Contact', data['contact_no']),
          ],
        ),
      ),
    );
  }

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

            _deliveryBoyProfileCard(data),
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

  Widget _deliveryBoyProfileCard(Map<String, dynamic> data) {
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
                (data['delivery_person_name'] ?? 'D')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['delivery_person_name'] ?? 'Delivery Boy',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['delivery_person_phone'] ?? 'Phone not available',
                    style: const TextStyle(fontSize: 12),
                  ),
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
