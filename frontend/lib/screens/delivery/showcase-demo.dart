// ignore: file_names
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class DeliveryHomePage extends StatefulWidget {
  final String deliveryId;
  final String name;

  const DeliveryHomePage({
    super.key,
    required this.deliveryId,
    required this.name,
  });

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Showcase keys
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _ordersKey = GlobalKey();
  final GlobalKey _statusKey = GlobalKey();
  final GlobalKey _drawerKey = GlobalKey();

  String _statusFilter = 'all'; // all | pending | sent | delivered

  @override
  void initState() {
    super.initState();

    // Start showcase after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowcaseView.get().startShowCase([
        _filterKey,
        _ordersKey,
        _statusKey,
        _drawerKey,
      ]);
    });
  }

  /// Restart showcase
  void _restartShowcase() {
    ShowcaseView.get().startShowCase([
      _filterKey,
      _ordersKey,
      _statusKey,
      _drawerKey,
    ]);
  }

  Stream<QuerySnapshot> get assignedOrders {
    return _firestore
        .collection('admin_orders')
        .where('deliveryPersonId', isEqualTo: widget.deliveryId)
        .snapshots();
  }

  // Future<void> _logout() async {
  //   await FirebaseAuth.instance.signOut();
  //   if (!mounted) return;

  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (_) => const LoginScreen()),
  //     (_) => false,
  //   );
  // }

  String _generate6DigitCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> updateDeliveryStatus(
    String orderId,
    String status, {
    String? code,
  }) async {
    final data = <String, dynamic>{'deliveryStatus': status};

    if (status == 'sent') {
      data['deliveryCode'] = code;
    }

    await _firestore.collection('admin_orders').doc(orderId).update(data);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery status updated')));
    }
  }

  Future<void> verifyCode(String orderId, String enteredCode) async {
    final doc = await _firestore.collection('admin_orders').doc(orderId).get();
    final data = doc.data();

    if (data == null || data['deliveryCode'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No code found')));
      return;
    }

    if (enteredCode == data['deliveryCode'].toString()) {
      await _firestore.collection('admin_orders').doc(orderId).update({
        'deliveryStatus': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryCode': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order delivered')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect code')));
    }
  }

  /// Safe Dropdown Showcase
  Widget buildOrderItem({
    required int index,
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required GlobalKey<State<StatefulWidget>> showcaseKey,
  }) {
    final safeSelectedValue = options.contains(selectedValue)
        ? selectedValue
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Showcase(
        key: showcaseKey,
        description: 'Select an option from the dropdown',
        tooltipActionConfig: const TooltipActionConfig(
          alignment: MainAxisAlignment.spaceBetween,
          position: TooltipActionPosition.outside,
          gapBetweenContentAndAction: 10,
        ),
        child: DropdownButtonFormField<String>(
          initialValue: safeSelectedValue,
          decoration: InputDecoration(
            labelText: 'Order Status',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: options
              .toSet() // remove duplicates if any
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Color(0xff537D4F),
      onSelected: (_) => setState(() => _statusFilter = value),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Showcase(
        key: _drawerKey,
        description: "Access logout and profile here",
        child: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xff537D4F)),
                accountName: Text(widget.name),
                accountEmail: const Text("Delivery Partner"),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text("Restart Walkthrough"),
                onTap: () {
                  Navigator.pop(context);
                  _restartShowcase();
                },
              ),
              // ListTile(
              //   leading: const Icon(Icons.logout, color: Colors.red),
              //   title: const Text("Logout"),
              //   onTap: _logout,
              // ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text("Welcome, ${widget.name}"),
        actions: [
          TextButton(
            onPressed: () => ShowcaseView.get().dismiss(),
            child: const Text("SKIP", style: TextStyle(color: Colors.white)),
          ),
        ],
        backgroundColor: Color(0xff537D4F),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Showcase(
              key: _filterKey,
              description: "Filter orders by status",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _filterChip("All", 'all'),
                  _filterChip("Pending", 'pending'),
                  _filterChip("Sent", 'sent'),
                  _filterChip("Delivered", 'delivered'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Showcase(
              key: _ordersKey,
              description: "Orders assigned to you",
              child: StreamBuilder<QuerySnapshot>(
                stream: assignedOrders,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orders = snapshot.data!.docs.where((doc) {
                    final s = (doc['deliveryStatus'] ?? 'pending').toString();
                    return _statusFilter == 'all' || s == _statusFilter;
                  }).toList();

                  if (orders.isEmpty) {
                    return const Center(child: Text("No orders assigned"));
                  }

                  // Status options
                  final List<String> statusOptions = [
                    'pending',
                    'sent',
                    'delivered',
                  ];

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final orderDoc = orders[i];
                      final currentStatus =
                          (orderDoc['deliveryStatus'] ?? 'pending').toString();

                      return buildOrderItem(
                        index: i,
                        selectedValue: currentStatus,
                        options: statusOptions,
                        showcaseKey: _statusKey, // non-null key
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {});
                          if (val == 'sent') {
                            final code = _generate6DigitCode();
                            updateDeliveryStatus(orderDoc.id, val, code: code);
                          } else {
                            updateDeliveryStatus(orderDoc.id, val);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
