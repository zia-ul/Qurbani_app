import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/location_picker.dart';

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

  /// Expanded based on qty
  List<Map<String, dynamic>> expandedCart = [];

  /// Final shareholders list
  List<Map<String, dynamic>> shareholders = [];

  /// animalId → animalType
  Map<String, String> animalTypeMap = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnimalsAndPrepareShareholders();
  }

  /// 🔥 JOIN cart → animals & prepare shareholders
  Future<void> _loadAnimalsAndPrepareShareholders() async {
    try {
      /// 1️⃣ Collect unique animalIds from cart
      final animalIds = widget.cartItems
          .map((e) => e['animalId'].toString())
          .toSet()
          .toList();

      /// 2️⃣ Fetch animals
      final animalDocs = await Future.wait(
        animalIds.map((id) => _firestore.collection('animals').doc(id).get()),
      );

      /// 3️⃣ Build animalId → type map
      for (var doc in animalDocs) {
        if (doc.exists) {
          animalTypeMap[doc.id] = (doc.data()?['type'] ?? 'Animal').toString();
        }
      }

      /// 4️⃣ Expand cart & create shareholders
      for (var item in widget.cartItems) {
        final animalId = item['animalId'].toString();
        final qty = int.tryParse(item['qty'].toString()) ?? 1;
        final animalType = animalTypeMap[animalId] ?? 'Animal';

        for (int i = 0; i < qty; i++) {
          expandedCart.add({'animalId': animalId, 'animalType': animalType});

          shareholders.add({
            'name': '',
            'parentName': '',
            'animalId': animalId,
            'animalType': animalType,
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading animals: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    contactController.dispose();
    addressController.dispose();
    super.dispose();
  }

  /// 🔥 Submit Order to Firestore
  Future<void> submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final orderRef = _firestore.collection('orders').doc();

    final totalAmount = widget.cartItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (double.tryParse(item['price'].toString()) ?? 0) *
              (int.tryParse(item['qty'].toString()) ?? 1),
    );

    final orderData = {
      'orderId': orderRef.id,
      'userId': widget.userId,
      'qurbaniDay': selectedDay,
      'contactDetails': contactController.text.trim(),
      'deliveryAddress': addressController.text.trim(),
      'shareholders': shareholders,
      'cartItems': widget.cartItems,
      'totalAmount': totalAmount,
      'paymentStatus': 'pending',
      'processingStatus': 'pending',
      'deliveryStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await orderRef.set(orderData);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order placed successfully')));
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
              /// Qurbani Day
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

              /// 🔥 Shareholders
              ...List.generate(shareholders.length, (index) {
                final animalType = shareholders[index]['animalType'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shareholder ${index + 1} for $animalType',
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

                    /// 🔒 Locked Animal Type
                    TextFormField(
                      initialValue: animalType,
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

              /// Contact
              TextFormField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Details',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),

              /// Address
              // TextFormField(
              //   controller: addressController,
              //   maxLines: 2,
              //   decoration: const InputDecoration(
              //     labelText: 'Delivery Address',
              //     border: OutlineInputBorder(),
              //   ),
              //   validator: (v) =>
              //       v == null || v.isEmpty ? 'Required' : null,
              // ),
              TextFormField(
                controller: addressController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Delivery Address',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.location_on),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationPickerPage(),
                        ),
                      );

                      if (result != null) {
                        addressController.text = result['address'];
                      }
                    },
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 20),

              Center(
                child: ElevatedButton(
                  onPressed: submitOrder,
                  child: const Text('Proceed to Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
