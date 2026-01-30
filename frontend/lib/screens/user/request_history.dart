import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:Qurbani/screens/user/payment_method_page.dart';
import 'package:Qurbani/theme/theme.dart';

class ProceedPage extends StatefulWidget {
  final String adminId;
  final List<Map<String, dynamic>> cartItems;
  final String userId;
  final Map<String, List<Map<String, dynamic>>> freeSlotsByDay;

  const ProceedPage({
    super.key,
    required this.adminId,
    required this.cartItems,
    required this.userId,
    required this.freeSlotsByDay,
  });

  @override
  State<ProceedPage> createState() => _ProceedPageState();
}

class _ProceedPageState extends State<ProceedPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> shareholders = [];
  Map<String, String> animalTypeMap = {}; // To store animal types for UI
  bool isLoading = true;

  final primaryPhoneController = TextEditingController();
  final addressController = TextEditingController();
  final buildingController = TextEditingController();
  final landmarkController = TextEditingController();

  String selectedPrimaryCode = "+971";
  final List<String> countryCodes = ["+971", "+91", "+92", "+1", "+44"];
  final List<String> qurbaniDays = ["Day 1", "Day 2", "Day 3"];

  final Color parchmentBg = const Color(0xFFF4F7F4);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await fetchUserData();
    await _prepareShareholders();
  }

  Future<void> fetchUserData() async {
    try {
      final doc = await _firestore.collection("users").doc(widget.userId).get();
      if (doc.exists) {
        setState(() {
          primaryPhoneController.text =
              doc.data()?['phone']?.toString().replaceAll(
                RegExp(r'[^\d]'),
                '',
              ) ??
              "";
          addressController.text = doc.data()?['address'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _prepareShareholders() async {
    try {
      // Fetch animal types for display
      final animalIds = widget.cartItems
          .map((e) => e['animalId'])
          .toSet()
          .toList();
      for (var id in animalIds) {
        final doc = await _firestore.collection('animals').doc(id).get();
        if (doc.exists) {
          animalTypeMap[id] = doc.data()?['animalType'] ?? 'Animal';
        }
      }

      List<Map<String, dynamic>> temp = [];
      for (var item in widget.cartItems) {
        final shares = int.tryParse(item['shares'].toString()) ?? 1;
        for (int i = 0; i < shares; i++) {
          temp.add({
            'name': '',
            'parentName': '',
            'animalId': item['animalId'],
            'animalType': animalTypeMap[item['animalId']] ?? 'Animal',
            'preferredDay': "Day 1",
            'selectedSlot': null,
          });
        }
      }
      setState(() {
        shareholders = temp;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error preparing shareholders: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> detectCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    try {
      final place = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = place.first;
      setState(() {
        addressController.text = "${p.street}, ${p.locality}, ${p.country}";
      });
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: parchmentBg,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStepperHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    ...shareholders.asMap().entries.map(
                      (entry) => _buildShareholderCard(entry.key, entry.value),
                    ),
                    const SizedBox(height: 10),
                    _buildDeliverySection(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      color: AppTheme.bgGradientEnd,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Column(
        children: [
          const Text(
            "Enter Shareholder Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Please fill in details for each share.",
            style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepItem("1", "Details", true),
              _stepLine(false),
              _stepItem("2", "Payment", false),
              _stepLine(false),
              _stepItem("3", "Review", false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepItem(String num, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? AppTheme.primaryGreen : Colors.grey[300],
          child: Text(
            num,
            style: const TextStyle(color: AppTheme.bgGradientEnd, fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppTheme.primaryGreen : AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(
      height: 2,
      color: active ? AppTheme.primaryGreen : Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 15),
    ),
  );

  Widget _buildShareholderCard(int index, Map<String, dynamic> s) {
    String dayKey = s["preferredDay"].toLowerCase().replaceAll(" ", "");
    List<Map<String, dynamic>> availableSlots =
        widget.freeSlotsByDay[dayKey] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD1C4A9).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                "Shareholder ${index + 1} (${s["animalType"]})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _inputLabel("Shareholder Name"),
          TextFormField(
            initialValue: s["name"],
            decoration: _inputDecoration("Enter name"),
            onChanged: (v) => shareholders[index]["name"] = v,
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          _inputLabel("Father/Mother Name"),
          TextFormField(
            initialValue: s["parentName"],
            decoration: _inputDecoration("Enter guardian name"),
            onChanged: (v) => shareholders[index]["parentName"] = v,
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel("Preferred Day"),
                    DropdownButtonFormField<String>(
                      value: s["preferredDay"],
                      isExpanded: true,
                      decoration: _inputDecoration("Day"),
                      items: qurbaniDays
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        shareholders[index]["preferredDay"] = v;
                        shareholders[index]["selectedSlot"] = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel("Available Slot"),
                    DropdownButtonFormField<String>(
                      value: s["selectedSlot"],
                      isExpanded: true,
                      decoration: _inputDecoration("Select time"),
                      items: availableSlots
                          .map(
                            (slot) => DropdownMenuItem(
                              value: slot['time'].toString(),
                              child: Text(slot['time']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => shareholders[index]["selectedSlot"] = v,
                      ),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Delivery Information",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 90,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedPrimaryCode,
                    items: countryCodes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedPrimaryCode = v!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: primaryPhoneController,
                  decoration: _inputDecoration("Phone Number"),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: addressController,
            decoration: _inputDecoration("Complete Address").copyWith(
              suffixIcon: IconButton(
                onPressed: detectCurrentLocation,
                icon: Icon(
                  Icons.my_location,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
            ),
            validator: (v) => v!.isEmpty ? "Address required" : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: buildingController,
                  decoration: _inputDecoration("Bldg/House No"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: landmarkController,
                  decoration: _inputDecoration("Landmark (Optional)"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, const Color(0xFF5A916E)],
        ),
      ),
      child: ElevatedButton(
        onPressed: submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: const Text(
          "Proceed to Payment",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black54,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen),
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGreen),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.warningRed),
      ),
    );
  }

  Future<void> submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = widget.cartItems.fold<double>(0, (sum, item) {
      double price = double.tryParse(item["price"].toString()) ?? 0.0;
      int shares = int.tryParse(item["shares"].toString()) ?? 1;
      return sum + (price * shares);
    });

    final orderData = {
      "userId": widget.userId,
      "adminId": widget.adminId,
      "contact": "$selectedPrimaryCode${primaryPhoneController.text.trim()}",
      "deliveryLocation": {
        "address": addressController.text.trim(),
        "buildingNumber": buildingController.text.trim(),
        "landmark": landmarkController.text.trim(),
      },
      "shareholders": shareholders,
      "cartItems": widget.cartItems,
      "totalAmount": totalAmount,
      "paymentStatus": "Pending",
      "orderStatus": "Processing",
      "createdAt": FieldValue.serverTimestamp(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodPage(orderData: orderData),
      ),
    );
  }
}
