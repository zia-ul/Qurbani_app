import 'dart:convert'; // For JSON parsing
// import 'package:Qurbani/services/currency_notifier.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/services/currency_notifier.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/screens/user/payment_processing_page.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart' as loc;

// class Shareholder {
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController guardianController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();

//   String qurbaniDay = 'Day 1';
//   String? selectedAnimalId;

//   bool useLiveLocation = false;
//   double? latitude;
//   double? longitude;

//   void dispose() {
//     nameController.dispose();
//     guardianController.dispose();
//     addressController.dispose();
//   }
// }

import 'package:country_state_city/country_state_city.dart' as csc;

class Shareholder {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController guardianController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();

  bool useLiveLocation = false;
  double? latitude;
  double? longitude;
  String qurbaniDay = 'Day 1';
  //
  String? selectedCountryName;
  String? countryISO;

  List<csc.State> states = [];
  List<csc.City> cities = [];

  csc.State? selectedState;
  csc.City? selectedCity;

  void dispose() {
    nameController.dispose();
    guardianController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
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
  // List<Map<String, dynamic>> _animals =
  // []; // Includes price, payment_methods, delivery_fee, etc.
  bool _allowCOD = false;
  bool _allowOnline = true;
  bool _paymentSettingsLoaded = false;

  static final String? _baseUrl = dotenv.env['BASE_URL'];
  DateTime? _codDeadline;
  Map<String, dynamic>? _pricing;

  @override
  void initState() {
    super.initState();
    // _fetchAnimals();
    _fetchPricing();
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

  Map<String, dynamic>? _savedAddress;

  Future<void> _fetchSavedAddress() async {
    final res = await http.get(
      Uri.parse("$_baseUrl/user/profile/address"),
      headers: {
        "Authorization":
            "Bearer ${await FlutterSecureStorage().read(key: 'token')}",
      },
    );

    if (res.statusCode == 200) {
      setState(() {
        _savedAddress = jsonDecode(res.body);
      });
    }
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

  Future<void> _getLiveLocation(Shareholder shareholder) async {
    final loc.Location location = loc.Location();

    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        Fluttertoast.showToast(
          msg: "Location services are disabled",
          backgroundColor: AppTheme.warningRed,
        );
        return;
      }
    }

    // Check permission
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        Fluttertoast.showToast(
          msg: "Location permission denied",
          backgroundColor: AppTheme.warningRed,
        );
        return;
      }
    }

    final loc.LocationData locationData = await location.getLocation();

    // 🔥 Reverse geocoding
    final placemarks = await placemarkFromCoordinates(
      locationData.latitude!,
      locationData.longitude!,
    );

    final place = placemarks.first;

    final address = [
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ].where((e) => e != null && e!.isNotEmpty).join(', ');

    setState(() {
      shareholder.latitude = locationData.latitude;
      shareholder.longitude = locationData.longitude;
      shareholder.addressController.text = address;
    });
  }

  // Future<void> _fetchAnimals() async {
  //   try {
  //     final result = await OrderService.getAnimals(widget.adminId);
  //     // result contains: {'admin_currency': 'USD', 'animals': [...]}
  //     final animals = List<Map<String, dynamic>>.from(result['animals']);

  //     setState(() {
  //       _animals = animals;
  //     });

  //     // debugPrint("Fetched animals: $_animals, currency: $_currency");
  //   } catch (e) {
  //     // debugPrint("Error fetching animals: $e");
  //     Fluttertoast.showToast(
  //       msg: "Error fetching animals: $e",
  //       backgroundColor: AppTheme.warningRed,
  //     );
  //   }
  // }

  Future<void> _fetchPricing() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("Not authenticated");
      }

      final res = await http.get(
        Uri.parse("$_baseUrl/admins/${widget.adminId}/share-pricing"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        debugPrint("Pricing API error: ${res.statusCode}");
        debugPrint(res.body);
        throw Exception("Failed to load pricing");
      }

      setState(() {
        _pricing = jsonDecode(res.body);
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error loading price per share",
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
    if (_pricing == null) return 0.0;

    final double pricePerShare =
        double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

    final int shareCount = _shareholders.length;

    double subtotal = pricePerShare * shareCount;

    double deliveryFee = 0.0;
    if (_pricing!['delivery_type'] == 'paid') {
      deliveryFee =
          double.tryParse(_pricing!['delivery_fee'].toString()) ?? 0.0;
    }

    return subtotal + deliveryFee;
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

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Use Live Location",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            value: shareholder.useLiveLocation,
            activeColor: AppTheme.primaryGreen,
            onChanged: (val) async {
              setState(() {
                shareholder.useLiveLocation = val;
                if (!val) {
                  shareholder.latitude = null;
                  shareholder.longitude = null;
                  shareholder.addressController.clear();
                }
              });

              if (val) {
                await _getLiveLocation(shareholder);
              }
            },
          ),

          if (!shareholder.useLiveLocation && _savedAddress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text("Use Saved Address"),
                onPressed: () {
                  setState(() {
                    shareholder.selectedCountryName = _savedAddress!['country'];
                    shareholder.selectedState = _savedAddress!['state'];
                    shareholder.selectedCity = _savedAddress!['city'];

                    shareholder.postalCodeController.text =
                        _savedAddress!['postal_code'] ?? '';
                    shareholder.addressController.text =
                        _savedAddress!['address'] ?? '';
                  });
                },
              ),
            ),

          const SizedBox(height: 10),

          // _customTextField(
          //   controller: shareholder.addressController,
          //   label: "Address",
          //   icon: Icons.location_on_outlined,
          //   enabled: !shareholder.useLiveLocation,
          // ),
          if (!shareholder.useLiveLocation) ...[
            _customTextField(
              controller: shareholder.addressController,
              label: "Address",
              icon: Icons.location_on,
            ),
            _customTextField(
              controller: shareholder.postalCodeController,
              label: "Postal Code",
              icon: Icons.markunread_mailbox,
            ),

            // const SizedBox(height: 15),
            // DropdownButtonFormField<String>(
            //   value: shareholder.selectedAnimalId,
            //   isExpanded: true,
            //   decoration: InputDecoration(
            //     labelText: "Select Animal",
            //     // prefixIcon: const Icon(
            //     //   Icons.online_prediction_rounded,
            //     //   color: AppTheme.primaryGreen,
            //     //   size: 20,
            //     // ),
            //     filled: true,
            //     fillColor: const Color(0xffF8F9FA), // SAME as text fields
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(12),
            //       borderSide: BorderSide.none,
            //     ),
            //     focusedBorder: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(12),
            //       borderSide: BorderSide(color: AppTheme.primaryGreen),
            //     ),
            //   ),
            //   hint: const Text("Choose an animal"),
            //   items: _animals.map((animal) {
            //     final basePrice =
            //         double.tryParse(animal['price'].toString()) ?? 0.0;
            //     final convertedPrice = currency.convert(basePrice);

            //     return DropdownMenuItem<String>(
            //       value: animal['id'],
            //       child: Text(
            //         "${animal['animal_type']} - "
            //         "${currency.currency} ${convertedPrice.toStringAsFixed(2)}",
            //       ),
            //     );
            //   }).toList(),
            //   onChanged: (value) {
            //     setState(() {
            //       shareholder.selectedAnimalId = value;
            //     });
            //   },
            // ),
            // const SizedBox(height: 20),
            Text(
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
                  onSelected: (_) =>
                      setState(() => shareholder.qurbaniDay = day),
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
        ],
      ),
    );
  }

  Widget _paymentSection() {
    final currency = context.read<CurrencyNotifier>();
    print(currency.currency);
    print(currency.baseCurrency);

    // double subtotal = 0.0;
    // double deliveryTotal = 0.0;

    // for (var shareholder in _shareholders) {
    //   if (shareholder.selectedAnimalId != null) {
    //     final animal = _animals.firstWhere(
    //       (a) => a['id'] == shareholder.selectedAnimalId,
    //       orElse: () => {'price': 0.0, 'delivery_fee': 0.0},
    //     );

    //     subtotal += double.tryParse(animal['price'].toString()) ?? 0.0;

    //     if (animal['delivery_type'] == 'Paid') {
    //       deliveryTotal +=
    //           double.tryParse(animal['delivery_fee'].toString()) ?? 0.0;
    //     }
    //   }
    // }

    if (_pricing == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final double pricePerShare =
        double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

    final int shareCount = _shareholders.length;

    final double subtotal = pricePerShare * shareCount;

    double deliveryFee = 0.0;
    if (_pricing!['delivery_type'] == 'paid') {
      deliveryFee =
          double.tryParse(_pricing!['delivery_fee'].toString()) ?? 0.0;
    }

    final double totalBase = subtotal + deliveryFee;

    // final totalBase = subtotal + deliveryTotal;

    // Convert ONLY for display
    final convertedSubtotal = currency.convert(subtotal);
    final convertedDelivery = currency.convert(totalBase);
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

  // Widget _paymentOption(String title, String value, IconData icon) {
  //   return RadioListTile<String>(
  //     title: Text(
  //       title,
  //       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  //     ),
  //     secondary: Icon(icon, color: AppTheme.primaryGreen),
  //     value: value,
  //     groupValue: _paymentMethod,
  //     onChanged: (val) => setState(() => _paymentMethod = val!),
  //     activeColor: AppTheme.primaryGreen,
  //     contentPadding: EdgeInsets.zero,
  //   );
  // }

  Widget _customTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
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

    if (_pricing == null) {
      Fluttertoast.showToast(
        msg: "Pricing not loaded",
        backgroundColor: AppTheme.warningRed,
      );
      return;
    }

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

    // ✅ Validate shareholders
    for (var s in _shareholders) {
      if (s.nameController.text.trim().isEmpty ||
          s.guardianController.text.trim().isEmpty ||
          s.addressController.text.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: "Please fill all fields",
          backgroundColor: AppTheme.warningRed,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final double pricePerShare =
          double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

      // ✅ Shareholders payload (NO animals)
      final shareholdersData = _shareholders.map((s) {
        return {
          'name': s.nameController.text.trim(),
          'guardianName': s.guardianController.text.trim(),
          'qurbaniDay': s.qurbaniDay,
          'address': s.addressController.text.trim(),
          'postalCode': s.postalCodeController.text.trim(),
          'price': pricePerShare,
        };
      }).toList();

      final double baseTotal = _calculateTotalPrice();
      final double displayTotal = currency.convert(baseTotal);

      // ✅ Cash confirmation
      if (_paymentMethod == 'Cash') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Order"),
            content: Text(
              "Total: ${currency.currency} "
              "${displayTotal.toStringAsFixed(2)}\n\n"
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

        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final String paymentStatus = _paymentMethod == 'Online'
          ? 'pending'
          : 'unpaid';

      final result = await OrderService.placeOrder(
        userId: '',
        adminId: widget.adminId,
        paymentMethod: _paymentMethod,
        shareholders: shareholdersData,
        totalAmount: baseTotal,
        paymentStatus: paymentStatus,
      );

      // ✅ Payment flow
      if (_paymentMethod == 'Online') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentProcessingPage(
              orderId: result['orderId'],
              totalAmount: baseTotal,
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
