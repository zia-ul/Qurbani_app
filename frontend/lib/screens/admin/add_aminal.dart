import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddAnimalPage extends StatefulWidget {
  const AddAnimalPage({super.key});

  @override
  State<AddAnimalPage> createState() => _AddAnimalPageState();
}

class _AddAnimalPageState extends State<AddAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final priceController = TextEditingController();
  final sharesController = TextEditingController();
  final customAnimalTypeController = TextEditingController();
  final deliveryFeeController = TextEditingController();
  final deliveryThresholdController = TextEditingController();
  final lastBookedDateController = TextEditingController();

  final _storage = const FlutterSecureStorage();

  String? selectedAnimalType;
  bool isDeliveryPaid = false;
  bool isLoading = false;
  DateTime? lastBookedDate;

  final Color lightBg = const Color(0xFFF9FBF9);
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  @override
  void dispose() {
    priceController.dispose();
    sharesController.dispose();
    customAnimalTypeController.dispose();
    deliveryFeeController.dispose();
    deliveryThresholdController.dispose();
    lastBookedDateController.dispose();
    super.dispose();
  }

  Future<void> pickLastBookedDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, 1, 1),
      lastDate: DateTime(now.year, 12, 31),
    );

    if (picked != null) {
      setState(() {
        lastBookedDate = picked;
        lastBookedDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> addAnimal() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedAnimalType == null) {
      ToastUtils.showError("Animal type is required");
      return;
    }

    if (lastBookedDate == null) {
      ToastUtils.showError("Last booking date is required");
      return;
    }

    final token = await _storage.read(key: "token");
    if (token == null) {
      ToastUtils.showError("Not authenticated");
      return;
    }

    setState(() => isLoading = true);

    try {
      final body = {
        "animalType": selectedAnimalType == "Others"
            ? customAnimalTypeController.text.trim()
            : selectedAnimalType,
        "price": double.parse(priceController.text.trim()),
        "shares": int.parse(sharesController.text.trim()),
        "lastBookedDate": lastBookedDate!.toIso8601String(),
        "deliveryType": isDeliveryPaid ? "paid" : "free",
        "deliveryFee": isDeliveryPaid
            ? double.parse(deliveryFeeController.text.trim())
            : 0,
        "deliveryThreshold":
            isDeliveryPaid && deliveryThresholdController.text.trim().isNotEmpty
            ? double.parse(deliveryThresholdController.text.trim())
            : null,
      };

      ;

      final res = await http.post(
        Uri.parse('$_baseUrl/animals'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (res.statusCode != 201) {
        throw Exception(jsonDecode(res.body)["message"]);
      }

      ToastUtils.showSuccess("Animal added successfully");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ToastUtils.showError("Failed to add animal: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const Text(
          "Add Animal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.bgGradientEnd,
        foregroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _card([
                      _label("Animal Type", required: true),
                      DropdownButtonFormField<String>(
                        decoration: _decoration("Select animal type"),
                        items: ["Goat", "Buffalo", "Sheep", "Camel", "Others"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedAnimalType = v),
                        validator: (v) => v == null ? "Required" : null,
                      ),
                      if (selectedAnimalType == "Others") ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: customAnimalTypeController,
                          decoration: _decoration("Enter custom animal type"),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Required" : null,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Price", required: true),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration("Enter price"),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      _label("Shares", required: true),
                      TextFormField(
                        controller: sharesController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration("Total shares"),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Required" : null,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Last Booking Date", required: true),
                      TextFormField(
                        controller: lastBookedDateController,
                        readOnly: true,
                        decoration: _decoration("Select date").copyWith(
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        onTap: pickLastBookedDate,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _card([
                      _label("Delivery Setup"),
                      SwitchListTile(
                        value: isDeliveryPaid,
                        onChanged: (v) => setState(() => isDeliveryPaid = v),
                        title: Text(
                          isDeliveryPaid ? "Paid Delivery" : "Free Delivery",
                        ),
                        activeColor: AppTheme.primaryGreen,
                      ),
                      if (isDeliveryPaid) ...[
                        TextFormField(
                          controller: deliveryFeeController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration("Delivery fee"),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: deliveryThresholdController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(
                            "Free delivery threshold (optional)",
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: addAnimal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                        child: const Text(
                          "Add Animal",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.bgGradientEnd,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        children: required
            ? const [
                TextSpan(
                  text: " *",
                  style: TextStyle(color: AppTheme.warningRed),
                ),
              ]
            : [],
      ),
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );
}
