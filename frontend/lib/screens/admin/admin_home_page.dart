import 'dart:math';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:qurbani/screens/admin/admin_drawer.dart';
import 'package:qurbani/screens/admin/add_aminal.dart';
import 'package:qurbani/screens/admin/admin_orders.dart';
import 'package:qurbani/screens/admin/special_requests_admin.dart';

class AdminHomePage extends StatefulWidget {
  final String adminId; // UUID from MySQL
  final String name;

  const AdminHomePage({
    super.key,
    required this.adminId,
    required this.name,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Color primaryGreen = const Color(0xff3D6B4E);
  final Color scaffoldBg = const Color(0xffF4F7F4);

  static const String _baseUrl = "https://your-api-url.com/api";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissions();
      await _ensureLocationSelected();
      _listenForNewOrders();
      _listenForDeliveryUpdates();
      _listenForRatings();
    });
  }

  // ---------------------------------------------------------
  // FIRESTORE LISTENERS (Realtime Notifications Only)
  // ---------------------------------------------------------

  void _listenForNewOrders() {
    _firestore
        .collection('admin_orders')
        .where('adminId', isEqualTo: widget.adminId)
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final data = docChange.doc.data();
          if (data == null) continue;

          if (data['newOrderPlacedNotified'] != true) {
            _triggerAdminNotification(
              title: "💰 New Order Received",
              body: "Order #${docChange.doc.id} has been placed.",
            );

            docChange.doc.reference.update({
              'newOrderPlacedNotified': true,
            });
          }
        }
      }
    });
  }

  void _listenForDeliveryUpdates() {
    _firestore
        .collection('admin_orders')
        .where('adminId', isEqualTo: widget.adminId)
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data();
          if (data == null) continue;

          final status = (data['deliveryStatus'] ?? '').toString().toLowerCase();
          if ((status == 'sent' || status == 'delivered') &&
              data['deliveryUpdateAdminNotified'] != true) {
            _triggerAdminNotification(
              title: "🚚 Delivery Update",
              body: "Order #${docChange.doc.id} is now $status",
            );

            docChange.doc.reference.update({
              'deliveryUpdateAdminNotified': true,
            });
          }
        }
      }
    });
  }

  void _listenForRatings() {
    _firestore
        .collection('admin_orders')
        .where('adminId', isEqualTo: widget.adminId)
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data();
          if (data == null) continue;

          if (data['rating'] != null &&
              data['ratingAdminNotified'] != true) {
            _triggerAdminNotification(
              title: "⭐ New Rating",
              body: "Order #${docChange.doc.id} received a rating",
            );

            docChange.doc.reference.update({
              'ratingAdminNotified': true,
            });
          }
        }
      }
    });
  }

  // ---------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------

  void _triggerAdminNotification({
    required String title,
    required String body,
  }) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100000),
        channelKey: 'admin_alerts',
        title: title,
        body: body,
        backgroundColor: primaryGreen,
      ),
    );
  }

  // ---------------------------------------------------------
  // PERMISSIONS
  // ---------------------------------------------------------

  Future<void> _checkPermissions() async {
    await [
      Permission.notification,
      Permission.camera,
      Permission.location,
    ].request();
  }

  // ---------------------------------------------------------
  // BACKEND LOCATION CHECK (JWT BASED)
  // ---------------------------------------------------------

  Future<void> _ensureLocationSelected() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final res = await http.get(
      Uri.parse("$_baseUrl/admin/profile"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['city'] == null) {
        // TODO: Show location picker
      }
    }
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      drawer: AdminDrawer(
        adminName: widget.name,
        adminId: widget.adminId,
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGreen),
        title: Text(
          "Admin Dashboard",
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _topActions(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Slot Summary",
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSlotSummary(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _actionCard(
            "Add Animal",
            Icons.add_circle_outline,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAnimalPage()),
            ),
          ),
          const SizedBox(height: 12),
          _actionCard(
            "View Orders",
            Icons.shopping_bag_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminOrdersPage(adminId: widget.adminId),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _actionCard(
            "Special Requests",
            Icons.message_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminSpecialRequestsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryGreen),
            const SizedBox(width: 15),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSummary() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("eidSlots").doc(widget.adminId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text("No slot data found");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final days = ["day 1", "day 2", "day 3"];

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (_, i) {
              final slots = data[days[i]] ?? [];
              final free = slots.where((s) => s["status"] == "Free").length;

              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, const Color(0xff5A916E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(days[i].toUpperCase(),
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text("$free Free",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
