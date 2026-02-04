import 'dart:convert'; // For JSON parsing
// import 'package:Qurbani/services/currency_notifier.dart';
import 'package:Qurbani/services/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/screens/user/payment_processing_page.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

class Shareholder {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController guardianController = TextEditingController();
  String qurbaniDay = 'Day 1';
  String? selectedAnimalId; // Use ID for selection

  void dispose() {
    nameController.dispose();
    guardianController.dispose();
  }
}

class QurbaniOrderPage extends StatefulWidget {
  final String adminId;

  const QurbaniOrderPage({super.key, required this.adminId});

  @override
  State<QurbaniOrderPage> createState() => _QurbaniOrderPageState();
}

class _QurbaniOrderPageState extends State<QurbaniOrderPage> {
  final Color bgGradientStart = const Color(0xffF2E8D5);
  final Color bgGradientEnd = const Color(0xffFFFFFF);

  final List<Shareholder> _shareholders = [];
  String _paymentMethod = 'Cash'; // Will be updated dynamically
  bool _isLoading = false;
  List<Map<String, dynamic>> _animals =
      []; // Includes price, payment_methods, delivery_fee, etc.
  bool _allowCOD = false;
  bool _allowOnline = true;
  bool _paymentSettingsLoaded = false;

  static final String? _baseUrl = dotenv.env['BASE_URL'];
  DateTime? _codDeadline;

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
    _fetchPaymentSettings();
    _addShareholder();
    // _fetchCurrency();
  }

  @override
  void dispose() {
    for (var s in _shareholders) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchPaymentSettings() async {
    try {
      final res = await http.get(
        Uri.parse("$_baseUrl/admins/${widget.adminId}/payment-settings"),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to load payment settings");
      }

      final data = jsonDecode(res.body);

      setState(() {
        _allowCOD = data['allow_cod'] == 1;
        _allowOnline = data['allow_online'] == 1;

        _codDeadline = data['cod_deadline'] != null
            ? DateTime.parse(data['cod_deadline'])
            : null;

        // Default payment method
        if (_allowOnline) {
          _paymentMethod = 'Online';
        } else if (_allowCOD) {
          _paymentMethod = 'Cash';
        }

        _paymentSettingsLoaded = true;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error loading payment settings",
        backgroundColor: AppTheme.warningRed,
      );
    }
  }

  // Future<void> _fetchCurrency() async {
  //   try {
  //     final res = await http.get(
  //       Uri.parse("$_baseUrl/admins/${widget.adminId}/currency"),
  //     );

  //     if (res.statusCode != 200) {
  //       throw Exception("Currency fetch failed");
  //     }

  //     final data = jsonDecode(res.body);

  //     setState(() {
  //       _currency = data['admin_currency'] ?? 'USD';
  //       _currencyRate = (data['rate'] ?? 1).toDouble();
  //       _currencyLoaded = true;
  //     });
  //   } catch (e) {
  //     debugPrint("Currency error: $e");
  //     setState(() {
  //       _currencyLoaded = true; // fallback
  //     });
  //   }
  // }

  // double _convert(double amount) {
  //   return amount * _currencyRate;
  // }

  Future<void> _fetchAnimals() async {
    try {
      final result = await OrderService.getAnimals(widget.adminId);
      // result contains: {'admin_currency': 'USD', 'animals': [...]}
      final animals = List<Map<String, dynamic>>.from(result['animals']);

      setState(() {
        _animals = animals;
      });

      // debugPrint("Fetched animals: $_animals, currency: $_currency");
    } catch (e) {
      // debugPrint("Error fetching animals: $e");
      Fluttertoast.showToast(
        msg: "Error fetching animals: $e",
        backgroundColor: AppTheme.warningRed,
      );
    }
  }

  void _addShareholder() {
    setState(() {
      _shareholders.add(Shareholder());
    });
  }

  void _removeShareholder(int index) {
    setState(() {
      _shareholders[index].dispose();
      _shareholders.removeAt(index);
    });
  }

  bool get isCODExpired {
    if (_codDeadline == null) return false;
    return DateTime.now().isAfter(_codDeadline!);
  }

  // Calculate total price: sum of animal prices + delivery fees
  double _calculateTotalPrice() {
    double subtotal = 0.0;
    double deliveryTotal = 0.0;

    for (var shareholder in _shareholders) {
      if (shareholder.selectedAnimalId != null) {
        final animal = _animals.firstWhere(
          (a) => a['id'] == shareholder.selectedAnimalId,
          orElse: () => {'price': 0.0, 'delivery_fee': 0.0},
        );

        subtotal += double.tryParse(animal['price'].toString()) ?? 0.0;

        if (animal['delivery_type'] == 'Paid') {
          deliveryTotal +=
              double.tryParse(animal['delivery_fee'].toString()) ?? 0.0;
        }
      }
    }

    final total = subtotal + deliveryTotal;

    // debugPrint("[TOTAL BASE] total=$total");
    return total; // BASE currency only
  }

  String _formatCodDeadline(DateTime date) {
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  // Get allowed payment methods from selected animals
  List<String> _getAllowedPaymentMethods() {
    final List<String> methods = [];

    if (_allowCOD) {
      methods.add('Cash');
    }

    if (_allowOnline) {
      methods.add('Online');
    }

    return methods;
  }

  @override
  Widget build(BuildContext context) {
    if (!_paymentSettingsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currency = context.read<CurrencyNotifier>();

    // Rest of your existing build method continues here...
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Shareholder Information",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    _shareholders.length,
                    (index) => _shareholderCard(index),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _addShareholder,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppTheme.primaryGreen,
                      ),
                      label: Text(
                        "Add Another Shareholder",
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Payment Summary",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _paymentSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Align(alignment: Alignment.bottomCenter, child: _buildBottomBar()),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shareholderCard(int index) {
    final currency = context.read<CurrencyNotifier>();
    final shareholder = _shareholders[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                radius: 18,
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_shareholders.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.warningRed,
                  ),
                  onPressed: () => _removeShareholder(index),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.nameController,
            label: "Full Name of Shareholder",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.guardianController,
            label: "Father / Guardian Name",
            icon: Icons.family_restroom_outlined,
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: shareholder.selectedAnimalId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "Select Animal",
              // prefixIcon: const Icon(
              //   Icons.online_prediction_rounded,
              //   color: AppTheme.primaryGreen,
              //   size: 20,
              // ),
              filled: true,
              fillColor: const Color(0xffF8F9FA), // SAME as text fields
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryGreen),
              ),
            ),
            hint: const Text("Choose an animal"),
            items: _animals.map((animal) {
              final basePrice =
                  double.tryParse(animal['price'].toString()) ?? 0.0;
              final convertedPrice = currency.convert(basePrice);

              return DropdownMenuItem<String>(
                value: animal['id'],
                child: Text(
                  "${animal['animal_type']} - "
                  "${currency.currency} ${convertedPrice.toStringAsFixed(2)}",
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                shareholder.selectedAnimalId = value;
              });
            },
          ),

          const SizedBox(height: 20),
          const Text(
            "Select Qurbani Day",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Day 1', 'Day 2', 'Day 3'].map((day) {
              bool isSelected = shareholder.qurbaniDay == day;
              return ChoiceChip(
                label: Text(day),
                selected: isSelected,
                selectedColor: AppTheme.primaryGreen,
                onSelected: (_) => setState(() => shareholder.qurbaniDay = day),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.bgGradientEnd : Colors.black,
                ),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _paymentSection() {
    final currency = context.read<CurrencyNotifier>();
    print(currency.currency);
    print(currency.baseCurrency);

    double subtotal = 0.0;
    double deliveryTotal = 0.0;

    for (var shareholder in _shareholders) {
      if (shareholder.selectedAnimalId != null) {
        final animal = _animals.firstWhere(
          (a) => a['id'] == shareholder.selectedAnimalId,
          orElse: () => {'price': 0.0, 'delivery_fee': 0.0},
        );

        subtotal += double.tryParse(animal['price'].toString()) ?? 0.0;

        if (animal['delivery_type'] == 'Paid') {
          deliveryTotal +=
              double.tryParse(animal['delivery_fee'].toString()) ?? 0.0;
        }
      }
    }

    final totalBase = subtotal + deliveryTotal;

    // ✅ Convert ONLY for display
    final convertedSubtotal = currency.convert(subtotal);
    final convertedDelivery = currency.convert(deliveryTotal);
    final convertedTotal = currency.convert(totalBase);

    debugPrint(
      "[PAYMENT] base=$totalBase ${currency.baseCurrency} → "
      "$convertedTotal ${currency.currency}",
    );

    final allowedMethods = _getAllowedPaymentMethods();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          ...allowedMethods.map((method) {
            return RadioListTile<String>(
              title: Text(method == 'Cash' ? 'Cash' : 'Online Payment'),
              value: method,
              groupValue: _paymentMethod,
              onChanged: (method == 'Cash' && isCODExpired)
                  ? null
                  : (val) => setState(() => _paymentMethod = val!),
              activeColor: AppTheme.primaryGreen,
            );
          }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgGradientStart.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _priceRow("Subtotal", convertedSubtotal, currency.currency),
                _priceRow(
                  "Delivery Charges",
                  convertedDelivery,
                  currency.currency,
                ),
                const Divider(),
                _priceRow(
                  "Total Price",
                  convertedTotal,
                  currency.currency,
                  isBold: true,
                  fontSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double amount,
    String currencySymbol, {
    bool isBold = false,
    double fontSize = 16,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          "$currencySymbol ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _paymentOption(String title, String value, IconData icon) {
    return RadioListTile<String>(
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      secondary: Icon(icon, color: AppTheme.primaryGreen),
      value: value,
      groupValue: _paymentMethod,
      onChanged: (val) => setState(() => _paymentMethod = val!),
      activeColor: AppTheme.primaryGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xffF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Confirm & Place Order",
            style: TextStyle(fontSize: 18, color: AppTheme.bgGradientEnd),
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    final allowedMethods = _getAllowedPaymentMethods();
    final currency = context.read<CurrencyNotifier>();

    if (!allowedMethods.contains(_paymentMethod)) {
      Fluttertoast.showToast(
        msg: "Selected payment method is not allowed",
        backgroundColor: AppTheme.warningRed,
      );
      return;
    }

    if (_paymentMethod == 'Cash' && isCODExpired) {
      Fluttertoast.showToast(
        msg: "Cash deadline has passed",
        backgroundColor: Colors.red,
      );
      return;
    }

    for (var s in _shareholders) {
      if (s.nameController.text.trim().isEmpty ||
          s.guardianController.text.trim().isEmpty ||
          s.selectedAnimalId == null) {
        Fluttertoast.showToast(
          msg: "Please fill all fields, including selecting an animal",
          backgroundColor: AppTheme.warningRed,
        );
        return;
      }
    }
    setState(() => _isLoading = true);
    try {
      final shareholdersData = _shareholders.map((s) {
        final animal = _animals.firstWhere(
          (a) => a['id'] == s.selectedAnimalId,
          orElse: () => throw Exception("Animal not found for shareholder"),
        );

        final double price = double.tryParse(animal['price'].toString()) ?? 0.0;

        final double deliveryFee = animal['delivery_type'] == 'Paid'
            ? double.tryParse(animal['delivery_fee'].toString()) ?? 0.0
            : 0.0;

        return {
          'name': s.nameController.text.trim(),
          'guardianName': s.guardianController.text.trim(),
          'qurbaniDay': s.qurbaniDay,
          'animalId': s.selectedAnimalId,
          'price': price, // per-animal price
          // 'deliveryFee': deliveryFee,
        };
      }).toList();

      if (_paymentMethod == 'Cash') {
        final baseTotal = _calculateTotalPrice();
        final displayTotal = currency.convert(baseTotal);

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Order"),
            content: Text(
              "Total: ${currency.currency} ${displayTotal.toStringAsFixed(2)}\n"
              "Place order with Cash?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        );
      }

      final String paymentStatus = _paymentMethod == 'Online'
          ? 'pending'
          : 'unpaid';

      final result = await OrderService.placeOrder(
        userId: '',
        adminId: widget.adminId,
        paymentMethod: _paymentMethod,
        shareholders: shareholdersData,
        totalAmount: _calculateTotalPrice(),
        paymentStatus: paymentStatus,
      );

      if (_paymentMethod == 'Online') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentProcessingPage(
              orderId: result['orderId'],
              totalAmount: _calculateTotalPrice(),
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Order placed successfully!",
          backgroundColor: AppTheme.accentGreen,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: AppTheme.warningRed,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
