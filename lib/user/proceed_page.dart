import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/location_picker.dart';
import 'package:qurbani1/user/payment_method_page.dart';

class ProceedPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String userId;

  const ProceedPage({super.key, required this.cartItems, required this.userId});

  @override
  State<ProceedPage> createState() => _ProceedPageState();
}

class _ProceedPageState extends State<ProceedPage> {
  final _formKey = GlobalKey<FormState>();

  final contactController = TextEditingController();
  final addressController = TextEditingController();

  String selectedDay = 'I';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> shareholders = [];
  Map<String, String> animalTypeMap = {};

  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prepareShareholders();
  }

  /// Prepare shareholders based on total shares
  Future<void> _prepareShareholders() async {
    try {
      final animalIds = widget.cartItems
          .map((e) => e['animalId'].toString())
          .toSet()
          .toList();

      final animalDocs = await Future.wait(
        animalIds.map((id) => _firestore.collection('animals').doc(id).get()),
      );

      for (var doc in animalDocs) {
        if (doc.exists) {
          animalTypeMap[doc.id] = (doc.data()?['type'] ?? 'Animal').toString();
        }
      }

      List<Map<String, dynamic>> tempShareholders = [];
      for (var item in widget.cartItems) {
        final animalId = item['animalId'].toString();
        final shares = int.tryParse(item['shares'].toString()) ?? 1;
        final animalType = animalTypeMap[animalId] ?? 'Animal';

        for (int i = 0; i < shares; i++) {
          tempShareholders.add({
            'name': '',
            'parentName': '',
            'gender': null,
            'animalId': animalId,
            'animalType': animalType,
          });
        }
      }

      setState(() {
        shareholders = tempShareholders;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading animals: $e')));
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    contactController.dispose();
    addressController.dispose();
    super.dispose();
  }

  /// Submit order: passes full order data to payment page
  Future<void> submitOrder() async {
    if (isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      // Calculate total amount
      final totalAmount = widget.cartItems.fold<double>(
        0,
        (sum, item) =>
            sum +
            (double.tryParse(item['price'].toString()) ?? 0) *
                (int.tryParse(item['shares'].toString()) ?? 1),
      );

      // Build full order data
      final orderData = {
        'userId': widget.userId,
        'qurbaniDay': selectedDay,
        'contactDetails': contactController.text.trim(),
        'deliveryAddress': addressController.text.trim(),
        'shareholders': shareholders
            .map(
              (s) => {
                'animalId': s['animalId'],
                'animalType': s['animalType'],
                'name': s['name'],
                'parentName': s['parentName'],
                'gender': s['gender'],
              },
            )
            .toList(),
        'cartItems': widget.cartItems,
        'totalAmount': totalAmount,
        'paymentStatus': 'Pending',
        'paymentMethod': null,
        'processingStatus': 'Pending',
        'deliveryStatus': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'specialRequestUsed': false
      };

      if (!mounted) return;

      // Navigate safely to PaymentMethodPage with required data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodPage(
            orderData: orderData, // ✅ ALWAYS passes required parameter
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shareholder Details'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Preferred Qurbani Day
              DropdownButtonFormField<String>(
                value: selectedDay,
                items: ['I', 'II', 'III']
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedDay = val!),
                decoration: const InputDecoration(
                  labelText: 'Preferred Qurbani Day',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              /// Shareholders fields
              ...List.generate(shareholders.length, (index) {
                final s = shareholders[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shareholder ${index + 1} for ${s['animalType']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Shareholder Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      onChanged: (v) => shareholders[index]['name'] = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Father / Mother Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      onChanged: (v) => shareholders[index]['parentName'] = v,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: shareholders[index]['gender'],
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => shareholders[index]['gender'] = val),
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: s['animalType'],
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Animal Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),

              /// Contact Details
              TextFormField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Details',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),

              /// Delivery Address
              /// Delivery Address
              TextFormField(
                controller: addressController,
                readOnly: false, // allow manual typing
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Delivery Address',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.green, // highlight icon
                    ),
                    tooltip: 'Use current location',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationPickerPage(),
                        ),
                      );
                      if (result != null && result['address'] != null) {
                        setState(() {
                          addressController.text = result['address'];
                        });
                      }
                    },
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              Center(
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitOrder,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Proceed to Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
