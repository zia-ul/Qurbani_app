import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
          primaryPhoneController.text = doc['phone'] != null
              ? doc['phone'].toString().replaceAll(RegExp(r'[^\d]'), '')
              : "";
          addressController.text = doc['address'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  Future<void> _prepareShareholders() async {
    List<Map<String, dynamic>> temp = [];
    for (var item in widget.cartItems) {
      final shares = int.tryParse(item['shares'].toString()) ?? 1;
      for (int i = 0; i < shares; i++) {
        temp.add({
          'name': '',
          'parentName': '',
          'gender': 'Male',
          'animalId': item['animalId'],
          'animalType': item['animalType'] ?? item['category'] ?? 'Animal',
          'preferredDay': "Day 1",
          'selectedSlot': null,
        });
      }
    }
    setState(() {
      shareholders = temp;
      isLoading = false;
    });
  }

  Future<void> detectCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    final pos = await Geolocator.getCurrentPosition();
    final place = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    final p = place.first;
    setState(() {
      addressController.text = "${p.street}, ${p.locality}, ${p.country}";
    });
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
        backgroundColor: Colors.white,
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Column(
        children: [
          const Text(
            "Enter Shareholder Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Please fill in the details below for each share.",
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
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
        color: Colors.white,
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
              // const Icon(Icons.keyboard, size: 18, color: Colors.orange),
              // const SizedBox(width: 8),
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
            decoration: _inputDecoration("Enter name"),
            onChanged: (v) => shareholders[index]["name"] = v,
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          _inputLabel("Father/Mother Name"),
          TextFormField(
            decoration: _inputDecoration("Enter guardian name"),
            onChanged: (v) => shareholders[index]["parentName"] = v,
            validator: (v) => v!.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: s["gender"] ?? "Male",
            items: [
              "Male",
              "Female",
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => shareholders[index]["gender"] = v),
            decoration: _inputDecoration("Gender"),
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
                      decoration: _inputDecoration("Select day"),
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
                      decoration: _inputDecoration("Select time"),
                      items: availableSlots
                          .map(
                            (slot) => DropdownMenuItem<String>(
                              value: slot['time'],
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
        color: Colors.white,
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

          //phone field validation
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntlPhoneField(
              controller: primaryPhoneController,
              initialCountryCode: 'AE',
              decoration: _inputDecoration("Phone Number").copyWith(
                counterText:
                    "", // Removes the character counter at the bottom if not needed
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.phone,
              languageCode: "en",
              // This provides automatic validation based on the selected country
              validator: (phone) {
                if (phone == null || phone.number.isEmpty) {
                  return 'Phone number is required';
                }
                try {
                  if (!phone.isValidNumber()) {
                    return 'Invalid phone number length';
                  }
                } catch (e) {
                  return 'Invalid phone number';
                }
                return null;
              },
              onChanged: (phone) {
                // You can access the full number with code: phone.completeNumber
                print(phone.completeNumber);
              },
              onCountryChanged: (country) {
                setState(() {
                  selectedPrimaryCode = "+${country.dialCode}";
                });
              },
            ),
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
            validator: (v) => v!.isEmpty ? "Required" : null,
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
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          "Proceed to Payment",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black54),
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
    );
  }

  Future<void> submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = widget.cartItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (double.tryParse(item["price"].toString()) ?? 0) *
              (int.tryParse(item["shares"].toString()) ?? 1),
    );

    final orderData = {
      "userId": widget.userId,
      "adminId": widget.adminId,
      "contact": {
        "primary": "$selectedPrimaryCode${primaryPhoneController.text.trim()}",
      },
      "deliveryLocation": {
        "address": addressController.text.trim(),
        "buildingNumber": buildingController.text.trim(),
        "landmark": landmarkController.text.trim(),
      },
      "shareholders": shareholders,
      "cartItems": widget.cartItems,
      "totalAmount": totalAmount,
      "paymentStatus": "Pending",
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
