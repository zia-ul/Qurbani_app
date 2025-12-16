import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrderDetailsPage extends StatefulWidget {
  final String orderId;
  final String processingStatus;
  final String deliveryStatus;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
    required this.processingStatus,
    required this.deliveryStatus,
  });

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool isUpdating = false;

  Map<String, dynamic> orderDetails = {};

  late String processingStatus;
  late String deliveryStatus;

  List<dynamic> cartItems = [];
  List<dynamic> deliveryPersons = [];
  String? selectedDeliveryPerson;

  final List<String> processingOptions = [
    'Qurbani started',
    'Qurbani Done',
    'Meat Processing & Packaging',
  ];

  final List<String> deliveryOptions = [
    'Packaging',
    'Out for Delivery',
    'Delivery Done',
  ];

  @override
  void initState() {
    super.initState();
    processingStatus = widget.processingStatus;
    deliveryStatus = widget.deliveryStatus;
    fetchOrderDetails();
    fetchDeliveryPersons();
  }

  // Fetch delivery persons from users table
  Future<void> fetchDeliveryPersons() async {
    final url = Uri.parse(
      'http://192.168.1.6/qurbani_api/get_delivery_persons.php',
    );
    final response = await http.get(url);

    print(response.body);

    try {
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          deliveryPersons = data['delivery_persons'];
        });
      }
    } catch (e) {
      print("Delivery JSON error: $e");
      print("Raw: ${response.body}");
    }
  }

  Future<void> fetchOrderDetails() async {
    final url = Uri.parse(
      'http://192.168.1.6/qurbani_api/get_order_details.php?order_id=${widget.orderId}',
    );
    final response = await http.get(url);

    final data = jsonDecode(response.body);

    if (data['status'] == 'success') {
      setState(() {
        orderDetails = data['order'];

        processingStatus =
            data['order']['processing_status'] ?? processingStatus;
        if (!processingOptions.contains(processingStatus)) {
          processingStatus = processingOptions[0];
        }

        deliveryStatus = data['order']['delivery_status'] ?? deliveryStatus;
        if (!deliveryOptions.contains(deliveryStatus)) {
          deliveryStatus = deliveryOptions[0];
        }

        selectedDeliveryPerson = data['order']['delivery_person_id']
            ?.toString();

        if (orderDetails['cart_items'] != null) {
          cartItems = orderDetails['cart_items'] is String
              ? jsonDecode(orderDetails['cart_items'])
              : orderDetails['cart_items'];
        }
      });
    }
  }

  Future<void> updateOrderStatus() async {
    setState(() {
      isUpdating = true;
    });

    final url = Uri.parse(
      'http://192.168.1.6/qurbani_api/update_order_status.php',
    );

    Map<String, String> body = {
      'order_id': widget.orderId,
      'processing_status': processingStatus,
      'delivery_status': deliveryStatus,
    };

    // Only send delivery_person_id if assigned
    if (selectedDeliveryPerson != null && selectedDeliveryPerson!.isNotEmpty) {
      body['delivery_person_id'] = selectedDeliveryPerson!;
    }

    try {
      final response = await http.post(url, body: body);

      print(response.body);

      // Parse JSON safely
      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Update failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() {
      isUpdating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.green,
      ),
      body: orderDetails.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text("Order ID: ${orderDetails['id']}"),
                  const SizedBox(height: 10),
                  Text("User ID: ${orderDetails['user_id']}"),

                  const SizedBox(height: 20),
                  const Text("Processing Status:"),
                  DropdownButton<String>(
                    value: processingStatus,
                    items: processingOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        processingStatus = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 20),
                  const Text("Delivery Status:"),
                  DropdownButton<String>(
                    value: deliveryStatus,
                    items: deliveryOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        deliveryStatus = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 20),
                  const Text("Assign Delivery Person:"),
                  DropdownButton<String>(
                    value: selectedDeliveryPerson,
                    hint: const Text("Select delivery person"),
                    items: deliveryPersons
                        .map(
                          (person) => DropdownMenuItem(
                            value: person['id'].toString(),
                            child: Text(person['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDeliveryPerson = value!;
                      });
                    },
                  ),

                  const Divider(height: 30),
                  const Text("Cart Items:"),

                  ...cartItems.map((item) {
                    final map = item as Map<String, dynamic>;
                    return ListTile(
                      title: Text(map['animal_type']),
                      subtitle: Text(
                        "Price: ${map['price']} × ${map['quantity']}",
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: isUpdating ? null : updateOrderStatus,
                    child: isUpdating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Order'),
                  ),
                ],
              ),
            ),
    );
  }
}
