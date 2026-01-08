import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/admin/barcode_page.dart';
import 'package:qurbani/exchange_rates.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  Map<String, dynamic>? orderData;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? selectedDeliveryPersonId;
  String? selectedDeliveryPersonName;
  List<Map<String, dynamic>> deliveryPersons = [];
  bool loadingDeliveryPersons = true;

  final List<String> processingOptions = [
    'Qurbani Started',
    'Qurbani Done',
    'Meat Processing & Packaging',
  ];

  late String processingStatus;
  final Color primaryGreen = const Color(0xff3D6B4E);
  final Color bgParchment = const Color(0xffF2E8D5);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadOrderData();
    await _loadDeliveryPersons();
    // Assuming UserCurrency is a static helper class
    // await UserCurrency.init();
    if (mounted) setState(() {});
  }

  // --- LOGIC: PERMISSIONS & NOTIFICATIONS ---
  Future<bool> _checkPermissions() async {
    // Check if permissions are already granted
    final locationStatus = await Permission.location.status;
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;

    // If any permission is not granted, request them
    if (locationStatus != PermissionStatus.granted ||
        cameraStatus != PermissionStatus.granted ||
        notificationStatus != PermissionStatus.granted) {
      final result = await [
        Permission.location,
        Permission.camera,
        Permission.notification,
      ].request();

      final allGranted =
          result[Permission.location] == PermissionStatus.granted &&
          result[Permission.camera] == PermissionStatus.granted &&
          result[Permission.notification] == PermissionStatus.granted;

      if (allGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions granted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some permissions were denied')),
        );
      }

      return allGranted;
    }

    return true; // All permissions already granted
  }

  // Request permissions on-demand when needed
  Future<bool> _requestPermissionsIfNeeded() async {
    return await _checkPermissions();
  }

  Future<void> _loadDeliveryPersons() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .get();

      setState(() {
        deliveryPersons = snap.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Delivery Person'})
            .toList();
        loadingDeliveryPersons = false;
      });
    } catch (e) {
      if (mounted) setState(() => loadingDeliveryPersons = false);
    }
  }

  Future<void> _loadOrderData() async {
    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .get();

      if (!orderSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Order not found')));
          Navigator.pop(context);
        }
        return;
      }

      orderData = orderSnap.data();
      processingStatus =
          processingOptions.contains(orderData!['processingStatus'])
          ? orderData!['processingStatus']
          : processingOptions.first;

      final userId = orderData!['userId'];
      if (userId != null) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userSnap.exists) userData = userSnap.data();
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _generateBarcode(String orderId, String animalId) {
    final raw = (animalId + orderId).replaceAll(RegExp(r'[^0-9]'), '');
    final base = raw.padRight(12, '0').substring(0, 12);
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(base[i]);
      sum += (i.isEven) ? digit : digit * 3;
    }
    return '$base${(10 - (sum % 10)) % 10}';
  }

  Future<void> _generateBarcodeByAdmin(String animalId) async {
    if (orderData == null) return;
    final items = List<Map<String, dynamic>>.from(
      orderData!['items'] ?? orderData!['cartItems'] ?? [],
    );
    final itemIndex = items.indexWhere((i) => i['animalId'] == animalId);
    if (itemIndex == -1) return;

    final barcode = _generateBarcode(widget.orderId, animalId);
    items[itemIndex].addAll({
      'barcode': barcode,
      'barcodeGenerated': true,
      'barcodeGeneratedBy': 'admin',
    });

    await FirebaseFirestore.instance
        .collection('admin_orders')
        .doc(widget.orderId)
        .update({'items': items});
    // Sync with main orders collection if necessary
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'items': items});

    await _loadOrderData();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Barcode generated')));
  }

  Future<void> _updateOrderInfo() async {
    setState(() => isLoading = true);
    var updates = {'processingStatus': processingStatus};

    if (selectedDeliveryPersonId != null) {
      updates['deliveryPersonId'] = selectedDeliveryPersonId!;
      updates['deliveryPersonName'] = selectedDeliveryPersonName!;
      updates['deliveryStatus'] = 'pending'; // Start with pending status
    }

    try {
      // Get current order data to check for status changes
      final currentOrderSnap = await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .get();

      final currentData = currentOrderSnap.data() ?? {};
      final currentProcessingStatus = currentData['processingStatus'] ?? '';
      final currentDeliveryStatus = currentData['deliveryStatus'] ?? '';

      // Check if processing status changed
      final bool processingStatusChanged =
          processingStatus != currentProcessingStatus;

      // Check if delivery status changed (only if we're assigning a delivery person)
      final bool deliveryStatusChanged =
          selectedDeliveryPersonId != null &&
          (currentDeliveryStatus != 'pending');

      // Reset notification flags if status changed
      if (processingStatusChanged) {
        updates['userProcessingNotified'] = 'false';
      }
      if (deliveryStatusChanged) {
        updates['userDeliveryNotified'] = 'false';
      }

      // Update the admin order document
      await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .update(updates);

      // Also update the main orders collection for consistency
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated successfully')),
      );

      // Send notification to user if status changed
      if (processingStatusChanged || deliveryStatusChanged) {
        await _sendNotificationToUserAlternative(
          processingStatusChanged,
          deliveryStatusChanged,
        );
      }

      _loadOrderData();
    } catch (e) {
      print('Unexpected error in _updateOrderInfo: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendNotificationToUserAlternative(
    bool processingChanged,
    bool deliveryChanged,
  ) async {
    try {
      // Get user ID from order
      final orderSnap = await FirebaseFirestore.instance
          .collection('admin_orders')
          .doc(widget.orderId)
          .get();

      if (!orderSnap.exists) return;

      final orderData = orderSnap.data()!;
      final userId = orderData['userId'];

      if (userId == null) return;

      // Prepare notification data
      String title = '';
      String body = '';

      if (processingChanged) {
        title = 'Processing Status Updated';
        body =
            'Your order #${widget.orderId.substring(0, 5)} processing status has been updated to: "$processingStatus"';
      } else if (deliveryChanged) {
        title = 'Delivery Status Updated';
        body =
            'Your order #${widget.orderId.substring(0, 5)} has been assigned for delivery';
      }

      // Send comprehensive notifications
      await _sendComprehensiveNotification(userId, title, body);
    } catch (e) {
      print('Error sending alternative notification: $e');
      // If everything fails, try local notification anyway
      try {
        await _sendLocalNotification(
          'Order Status Updated',
          'Your order status has been changed by admin',
        );
      } catch (localError) {
        print('Local notification also failed: $localError');
      }
    }
  }

  // Comprehensive notification system
  Future<void> _sendComprehensiveNotification(
    String userId,
    String title,
    String body,
  ) async {
    try {
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'];

      // 1. Send FCM notification if token exists
      if (fcmToken != null) {
        await _sendFCMNotification(fcmToken, title, body);
      }

      // 2. Send local notification using Awesome Notifications
      await _sendLocalNotification(title, body);

      // 3. Create notification record in database for persistent notifications
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'orderId': widget.orderId,
        'type': 'status_update',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high',
      });

      print('Comprehensive notification sent: $title');
    } catch (e) {
      print('Error in comprehensive notification: $e');
      // Fallback to local notification only
      try {
        await _sendLocalNotification(title, body);
      } catch (localError) {
        print('Local notification also failed: $localError');
      }
    }
  }

  Future<void> _sendFCMNotification(
    String token,
    String title,
    String body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'key=YOUR_SERVER_KEY', // You need to replace this with your actual server key
        },
        body: jsonEncode({
          'to': token,
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done',
          },
        }),
      );

      print('FCM Response: ${response.statusCode}');
    } catch (e) {
      print('FCM Error: $e');
    }
  }

  // Alternative notification method using local notifications only
  Future<void> _sendLocalNotification(String title, String body) async {
    try {
      // Use Awesome Notifications for local notifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          channelKey: 'user_orders',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
        ),
      );
      print('Local notification sent successfully');
    } catch (e) {
      print('Local notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgParchment,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfoSection(),
                  const Divider(),
                  _buildSelectionControls(),
                  const SizedBox(height: 20),
                  _buildUpdateActionButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildAnimalsListSection(),
            const SizedBox(height: 20),
            _buildShareholdersSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            "Order ID:",
            "#${widget.orderId.substring(0, 5)}",
            secondLabel: "User ID:",
            secondValue: "#${orderData?['userId']?.substring(0, 5) ?? 'N/A'}",
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Payment Status",
                  style: TextStyle(color: Color(0xff537D4F), fontSize: 13),
                ),
              ),
              _statusBadge(orderData?['paymentStatus'] ?? 'Unpaid'),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            "Method:",
            orderData?['paymentMethod'] == 'cod' ? "COD" : "Online",
          ),
          const SizedBox(height: 8),
          _infoRow(
            "Contact:",
            userData?['phone'] ?? orderData?['contact']?['primary'] ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _infoRow(
            "Address:",
            orderData!['deliveryLocation']?['address'] ??
                orderData!['deliveryAddress'] ??
                'N/A',
          ),
          const SizedBox(height: 8),
          // _infoRow(
          //   "Total:",
          //   UserCurrency.convert(
          //     orderData!['totalAmount'] ?? 0,
          //   ).toStringAsFixed(2),
          //   isCurrency: true,
          // ),
        ],
      ),
    );
  }

  Widget _buildSelectionControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Update Processing Status",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: processingStatus,
            decoration: _inputDecoration(),
            items: processingOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => processingStatus = v!),
          ),
          const SizedBox(height: 16),
          const Text(
            "Assign Delivery Person",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (loadingDeliveryPersons)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              value:
                  (deliveryPersons.any(
                    (d) => d['id'] == selectedDeliveryPersonId,
                  ))
                  ? selectedDeliveryPersonId
                  : (deliveryPersons.any(
                      (d) => d['id'] == orderData!['deliveryPersonId'],
                    ))
                  ? orderData!['deliveryPersonId']
                  : null,
              decoration: _inputDecoration(),
              hint: const Text("Select delivery person"),
              items: deliveryPersons
                  .map(
                    (d) => DropdownMenuItem<String>(
                      value: d['id'].toString(),
                      child: Text(d['name']),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                final match = deliveryPersons.firstWhere((e) => e['id'] == val);
                setState(() {
                  selectedDeliveryPersonId = match['id'];
                  selectedDeliveryPersonName = match['name'];
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUpdateActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _updateOrderInfo,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "SAVE CHANGES",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalsListSection() {
    final items = List<Map<String, dynamic>>.from(
      orderData!['items'] ?? orderData!['cartItems'] ?? [],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Animals In Order",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...items.map((item) {
          final bool barcodeGenerated = item['barcodeGenerated'] == true;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['imageUrl'] ?? item['photoUrl'] ?? '',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.pets,
                            size: 40,
                            color: Color(0xff537D4F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['animalType'] ?? 'Animal',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Shares: ${item['shares']}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff537D4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Barcode: ${barcodeGenerated ? item['barcode'] : 'Pending'}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: barcodeGenerated
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: barcodeGenerated
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BarcodePage(
                                    barcodeValue: item['barcode'],
                                  ),
                                ),
                              )
                            : () async {
                                // Request permissions before generating barcode
                                final hasPermissions =
                                    await _requestPermissionsIfNeeded();
                                if (hasPermissions) {
                                  _generateBarcodeByAdmin(item['animalId']);
                                }
                              },
                        icon: Icon(
                          barcodeGenerated ? Icons.qr_code : Icons.add,
                          size: 16,
                        ),
                        label: Text(barcodeGenerated ? "View" : "Generate"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: barcodeGenerated
                              ? Colors.blueGrey
                              : Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildShareholdersSection() {
    final shareholders = List<Map<String, dynamic>>.from(
      orderData!['shareholders'] ?? [],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Shareholders",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...shareholders.map(
          (s) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.black12),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.black12,
                child: Icon(Icons.person, color: Colors.black54),
              ),
              title: Text(
                s['name'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Day: ${s['preferredDay']} | Slot: ${s['selectedSlot'] ?? 'Not assigned'}",
              ),
              trailing: Icon(
                Icons.check_circle,
                color: s['selectedSlot'] != null
                    ? primaryGreen
                    : Color(0xff537D4F),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    String? secondLabel,
    String? secondValue,
    bool isCurrency = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13),
              children: [
                TextSpan(
                  text: "$label ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // TextSpan(
                //   text: isCurrency ? "${UserCurrency.currency} $value" : value,
                // ),
              ],
            ),
          ),
        ),
        if (secondLabel != null)
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 13),
                children: [
                  TextSpan(
                    text: "$secondLabel ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: secondValue!),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.black12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.black12),
    ),
  );
}
