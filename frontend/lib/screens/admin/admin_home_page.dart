import 'dart:math';
import 'dart:convert';
import 'dart:async'; // For Timer

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani/drawer.dart';
import 'package:qurbani/screens/admin/add_aminal.dart';

import 'package:qurbani/screens/admin/admin_orders.dart';
import 'package:qurbani/screens/admin/animal_listing.dart';
import 'package:qurbani/screens/admin/special_requests_admin.dart';
import 'package:qurbani/services/admin_service.dart';
import 'package:qurbani/theme/theme.dart'; // For stats and notifications

class AdminHomePage extends StatefulWidget {
  final String adminId;
  final String name;

  const AdminHomePage({super.key, required this.adminId, required this.name});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _baseUrl = "http://192.168.1.6:3000/api";

  Map<String, dynamic>? _stats;
  Timer? _notificationTimer; // For polling notifications

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissions();
      await _ensureLocationSelected();
      await _loadStats();
      _startNotificationPolling(); // Start polling for notifications
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      _stats = await AdminService.getDashboardStats();
      setState(() {});
    } catch (e) {
      // Handle silently or show error
    }
  }

  // ---------------------------------------------------------
  // POLLING FOR NOTIFICATIONS (Replaces Firestore Listeners)
  // ---------------------------------------------------------

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        final notifications = await AdminService.getNotifications();
        for (final notification in notifications) {
          String title = '';
          String body = '';

          switch (notification['type']) {
            case 'new_order':
              title = "💰 New Order Received";
              body = "Order #${notification['order_id']} has been placed.";
              break;
            case 'delivery_update':
              title = "🚚 Delivery Update";
              body = "Order #${notification['order_id']} status updated.";
              break;
            case 'rating':
              title = "⭐ New Rating";
              body = "Order #${notification['order_id']} received a rating.";
              break;
          }

          if (title.isNotEmpty) {
            _triggerAdminNotification(title: title, body: body);
            // Mark as notified in backend
            await AdminService.markNotificationNotified(notification['id']);
          }
        }
      } catch (e) {
        // Handle silently to avoid spam
        debugPrint("Error polling notifications: $e");
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
        backgroundColor: AppTheme.primaryGreen,
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent, // For gradient
      drawer: MasterDrawer(
        name: widget.name,
        id: widget.adminId,
        role: 'admin',
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryGreen),
        title: Text(
          "Admin Dashboard",
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 20),

            // Stats Section
            _buildStatsSection(),
            const SizedBox(height: 30),

            // Quick Actions
            _buildQuickActions(screenWidth),
            const SizedBox(height: 30),

            // Slot Summary (if needed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Slot Summary",
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // _buildSlotSummary(), // Uncomment and implement if needed
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, const Color(0xff5A916E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Assalamu Alaikum,",
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Manage your Qurbani operations efficiently.",
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCard("Animals", _stats!['animals'] ?? 0, Icons.pets),
          _statCard("Orders", _stats!['orders'] ?? 0, Icons.shopping_cart),
          _statCard("Requests", _stats!['requests'] ?? 0, Icons.message),
        ],
      ),
    );
  }

  Widget _statCard(String title, int count, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 28),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(double screenWidth) {
    final crossAxisCount = screenWidth > 600 ? 2 : 1; // Responsive grid

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3, // Adjust for card height
        children: [
          _actionCard(
            "Add Animal",
            Icons.add_circle_outline,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAnimalPage()),
            ),
          ),
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
          _actionCard(
            "Animal Management",
            Icons.inventory,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AnimalListingPage(), // Assuming you have this
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
      borderRadius: BorderRadius.circular(12),
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
            CircleAvatar(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              child: Icon(icon, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
