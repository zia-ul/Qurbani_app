import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:Qurbani/screens/admin/add_animal_details.dart';
import 'package:Qurbani/services/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/admin_order_service.dart';
import 'package:Qurbani/services/user_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

class ShareholderOrderDetails extends StatefulWidget {
  final String orderId;

  const ShareholderOrderDetails({super.key, required this.orderId});

  @override
  State<ShareholderOrderDetails> createState() =>
      _ShareholderOrderDetailsState();
}

class _ShareholderOrderDetailsState extends State<ShareholderOrderDetails> {
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

  /// Temporary selected payment values per shareholder
  final Map<String, String> _tempPaymentStatus = {};
  final Map<String, String> _tempAnimalId = {};
  final Map<String, int> _tempShareNumber = {};

  /// Initializes the state of the widget by fetching order details and delivery boys list.
  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchDeliveryBoys();
    fetchAnimals();
  }

  // -------- STEP STATE GETTERS --------

  bool hasAnimal(Map<String, dynamic> s) => s['animal_id'] != null;
  bool hasSchedule(Map<String, dynamic> s) => s['qurbani_datetime'] != null;
  bool hasDelivery(Map<String, dynamic> s) => s['delivery_person_id'] != null;

  String formatAddress(String? rawAddress) {
    if (rawAddress == null || rawAddress.isEmpty) return "N/A";

    try {
      final decoded = jsonDecode(rawAddress);

      final country = decoded['country'] ?? '';
      final state = decoded['state'] ?? '';
      final city = decoded['city'] ?? '';
      final street = decoded['street'] ?? '';

      return [
        street,
        city,
        state,
        country,
      ].where((e) => e.isNotEmpty).join(', ');
    } catch (e) {
      return rawAddress; // fallback if not JSON
    }
  }

  /// Fetches the detailed information of the order from the server using the order ID.
  Future<void> _fetchOrderDetails() async {
    try {
      orderData = await AdminOrderService.getAdminOrderById(widget.orderId);
      // processing = orderData!['processing_status'];
      print("order data in details page...$orderData");
      // selectedDeliveryBoyId = orderData!['delivery_person_id']?.toString();
    } catch (e) {
      ToastUtils.showError('Failed to load order: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateDeliveryStatus(
    String shareholderId,
    String status,
  ) async {
    final token = await _storage.read(key: 'token');

    final response = await http.post(
      Uri.parse("$_baseUrl/shareholders/$shareholderId/delivery-status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"delivery_status": status}),
    );

    if (response.statusCode == 200) {
      ToastUtils.showSuccess("Delivery status updated");
      await _fetchOrderDetails();
    } else {
      ToastUtils.showError("Failed to update delivery status");
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

  // FETch animals

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

      print("fetch animals response...${response.body}");

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
      body: jsonEncode({"animal_id": animalId, "share_number": shareNumber}),
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
    DateTime dateTime,
  ) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$_baseUrl/shareholders/$shareholderId/schedule"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"qurbani_datetime": dateTime.toIso8601String()}),
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Qurbani scheduled successfully");
        await _fetchOrderDetails();
      } else {
        ToastUtils.showError("Failed to schedule");
      }
    } catch (e) {
      ToastUtils.showError("Something went wrong");
    }
  }

  Future<void> _assignDeliveryToShareholder(
    String shareholderId,
    String deliveryBoyId,
  ) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$_baseUrl/shareholders/$shareholderId/assign-delivery"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"delivery_person_id": deliveryBoyId}),
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Delivery assigned successfully");
        await _fetchOrderDetails();
      } else {
        ToastUtils.showError("Failed to assign delivery");
      }
    } catch (e) {
      ToastUtils.showError("Something went wrong");
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
          const SizedBox(height: 16),

          /// ================= STEP FLOW =================
          ...shareholders.map((s) => _shareholderFlowCard(s)),
        ],
      ),
    );
  }

  /// Builds a card displaying the main order information, including user details, price, payment status, and a button to mark as paid if applicable.
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
            _infoRow('Address', data['address']),
            // _infoRow('Animal Type', data['animal_type']),
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

  Widget _shareholderFlowCard(Map<String, dynamic> shareholder) {
    final String shareholderId = shareholder['id'];

    print("shareholder details...$shareholder");

    final String paymentStatus = shareholder['payment_status'] ?? 'unpaid';
    final bool isPaid = paymentStatus == 'paid';

    final String? animalId = shareholder['animal_id'];
    final bool hasAnimal = animalId != null;

    final DateTime? schedule = shareholder['qurbani_datetime'] != null
        ? DateTime.parse(shareholder['qurbani_datetime'])
        : null;

    // final String? deliveryPersonId = shareholder['delivery_person_id'];
    final deliveryStatus = shareholder['delivery_status'] ?? 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Text(
              "Shareholder: ${shareholder['shareholder_name']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatAddress(shareholder['address']),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _buildStepIndicator(
              title: "Payment",
              isActive: paymentStatus == 'unpaid',
              isCompleted: paymentStatus == 'paid',
            ),

            const SizedBox(height: 8),

            _buildStepIndicator(
              title: "Animal",
              isActive: isPaid && !hasAnimal,
              isCompleted: hasAnimal,
            ),

            const SizedBox(height: 8),

            _buildStepIndicator(
              title: "Schedule",
              isActive: hasAnimal && schedule == null,
              isCompleted: schedule != null,
            ),

            const SizedBox(height: 8),

            _buildStepIndicator(
              title: "Delivery",
              isActive: deliveryStatus == 'sent',
              isCompleted: deliveryStatus == 'delivered',
            ),

            const Divider(height: 30),

            /// ================= STEP 1 PAYMENT =================
            if (paymentStatus == 'unpaid') ...[
              DropdownButtonFormField<String>(
                value: _tempPaymentStatus[shareholderId] ?? 'unpaid',
                decoration: const InputDecoration(
                  labelText: 'Payment Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _tempPaymentStatus[shareholderId] = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final selected =
                        _tempPaymentStatus[shareholderId] ?? 'unpaid';

                    if (selected == 'unpaid') {
                      ToastUtils.showError("Please select Paid");
                      return;
                    }

                    await _updateShareholderPayment(shareholderId, selected);

                    _tempPaymentStatus.remove(shareholderId);
                  },
                  child: const Text("Save Payment"),
                ),
              ),

              const SizedBox(height: 16),
            ] else ...[
              /// If already paid → show badge only
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      "Completed",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            /// ================= STEP 2 ANIMAL =================
            if (isPaid && !hasAnimal) ...[
              DropdownButtonFormField<String>(
                value: _tempAnimalId[shareholderId],
                decoration: const InputDecoration(
                  labelText: 'Select Animal',
                  border: OutlineInputBorder(),
                ),
                items: availableAnimals
                    .where((animal) {
                      final remaining =
                          int.tryParse(animal['remaining_shares'].toString()) ??
                          0;
                      return remaining > 0;
                    })
                    .map((animal) {
                      return DropdownMenuItem<String>(
                        value: animal['id'].toString(),
                        child: Text(
                          "${animal['animal_type']} "
                          "(Remaining: ${animal['remaining_shares']})",
                        ),
                      );
                    })
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _tempAnimalId[shareholderId] = value;
                    _tempShareNumber.remove(shareholderId);

                    // ✅ Set selectedAnimal properly
                    selectedAnimal = availableAnimals.firstWhere(
                      (animal) => animal['id'].toString() == value,
                    );
                  });
                },
              ),

              const SizedBox(height: 12),

              /// SHARE NUMBER DROPDOWN
              if (_tempAnimalId[shareholderId] != null)
                DropdownButtonFormField<int>(
                  value: _tempShareNumber[shareholderId],
                  decoration: const InputDecoration(
                    labelText: 'Select Share Number',
                    border: OutlineInputBorder(),
                  ),
                  items: () {
                    final animal = availableAnimals.firstWhere(
                      (a) => a['id'].toString() == _tempAnimalId[shareholderId],
                      orElse: () => {},
                    );

                    final int totalShares = animal['shares'] ?? 0;

                    return List.generate(totalShares, (index) => index + 1)
                        .map(
                          (share) => DropdownMenuItem<int>(
                            value: share,
                            child: Text("Share $share"),
                          ),
                        )
                        .toList();
                  }(),

                  onChanged: (value) {
                    setState(() {
                      _tempShareNumber[shareholderId] = value!;
                    });
                  },
                ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
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
                  },
                  child: const Text("Save Animal Assignment"),
                ),
              ),

              const SizedBox(height: 16),
            ] else if (isPaid && hasAnimal) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Animal Assigned (Share ${shareholder['share_number']})",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// ================= STEP 3 SCHEDULE =================
            if (isPaid && hasAnimal) ...[
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDate: DateTime.now(),
                  );
                  if (date == null) return;

                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time == null) return;

                  final dt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );

                  await _assignScheduleToShareholder(shareholderId, dt);
                },
                child: Text(
                  schedule != null
                      ? "Scheduled: ${schedule.toLocal()}"
                      : "Set Qurbani Date & Time",
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// ================= STEP 4 DELIVERY =================
            /// ================= STEP 4 DELIVERY =================
            if (isPaid && hasAnimal && schedule != null) ...[
              DropdownButtonFormField<String>(
                value: shareholder['delivery_status'] ?? 'pending',
                decoration: const InputDecoration(
                  labelText: 'Delivery Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'sent',
                    child: Text('Sent for Delivery'),
                  ),
                  DropdownMenuItem(
                    value: 'delivered',
                    child: Text('Delivered'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  await _updateDeliveryStatus(shareholderId, value);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color color;

    if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = AppTheme.primaryGreen;
    } else {
      color = Colors.grey.shade400;
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Container(),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Future<void> _updateShareholderPayment(
    String shareholderId,
    String status,
  ) async {
    final token = await _storage.read(key: 'token');

    await http.post(
      Uri.parse("$_baseUrl/shareholders/$shareholderId/payment"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"payment_status": status}),
    );

    ToastUtils.showSuccess("Payment updated successfully");

    await _fetchOrderDetails();
  }

  // -------------------- UI HELPERS --------------------

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
}
