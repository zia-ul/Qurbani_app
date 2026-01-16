import 'dart:math';
import 'dart:convert';
import 'dart:async'; // For Timer

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/drawer.dart';
import 'package:Qurbani/screens/admin/add_aminal.dart';
import 'package:Qurbani/screens/admin/admin_orders.dart';
import 'package:Qurbani/screens/admin/animal_listing.dart';
import 'package:Qurbani/screens/admin/special_requests_admin.dart';
import 'package:Qurbani/services/admin_service.dart';
import 'package:Qurbani/theme/theme.dart';

class AdminHomePage extends StatefulWidget {
  final String adminId;
  final String name;

  const AdminHomePage({super.key, required this.adminId, required this.name});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Color bgGradientStart = const Color(0xffF2E8D5); // Parchment style
  final Color bgGradientEnd = const Color(0xffFFFFFF);

  static const String _baseUrl = "http://192.168.1.6:3000/api";

  Map<String, dynamic>? _stats;
  Timer? _notificationTimer; // For polling notifications

  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissions();
      await _ensureLocationSelected();
      await _loadStats();
      _startNotificationPolling();
      _startStatsPolling(); // Start live stats polling
      await _checkNotificationPermission();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _statsTimer?.cancel(); // 🔥 Cancel stats timer
    super.dispose();
  }

  void _startStatsPolling() {
    _statsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _loadStats(); // reload stats from backend
    });
  }

  Future<void> _checkNotificationPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats =
          await AdminService.getDashboardStats(); // fetch from backend
      setState(() {
        _stats = stats; // update UI
      });
    } catch (e) {
      debugPrint("Error loading stats: $e");
      // optional: show toast or ignore
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
        wakeUpScreen: true,
        criticalAlert: true,
        notificationLayout: NotificationLayout.Default,
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
    return Scaffold(
      drawer: MasterDrawer(
        name: widget.name,
        id: widget.adminId,
        role: 'admin',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: AppTheme.primaryGreen),
              title: Text(
                "Admin Dashboard",
                style: TextStyle(
                  color: AppTheme.darkBgGradientStart,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ElevatedButton(
                    //   onPressed: () {
                    //     _triggerAdminNotification(
                    //       title: "Test Admin Notification",
                    //       body: "If you see this, it works 🎉",
                    //     );
                    //   },
                    //   child: const Text("TEST NOTIFICATION"),
                    // ),
                    Text(
                      "Assalamu Alaikum,",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.darkBgGradientStart,
                      ),
                    ),
                    Text(
                      "${widget.name}!",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff2D3E50),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Manage your Qurbani operations efficiently.",
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 25),

                    // FEATURE BAR (Admin Stats or Features)
                    _buildFeatureBanner(),
                    const SizedBox(height: 30),

                    // MAIN ACTION CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: "Add Animal",
                            subtitle: "List new animals",
                            icon: Icons.add_circle_outline,
                            color: const Color(0xff4CAF50),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddAnimalPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildActionCard(
                            title: "View Orders",
                            subtitle: "Track all orders",
                            icon: Icons.shopping_bag_outlined,
                            color: const Color(0xff2196F3),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminOrdersPage(adminId: widget.adminId),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: "Special Requests",
                            subtitle: "Handle custom orders",
                            icon: Icons.message_outlined,
                            color: const Color(0xffFF9800),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AdminSpecialRequestsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildActionCard(
                            title: "Animal Management",
                            subtitle: "Edit & manage listings",
                            icon: Icons.inventory,
                            color: const Color(0xff9C27B0),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AnimalListingPage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildSupportFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBanner() {
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _featureItem(
            FontAwesomeIcons.rectangleList,
            "Animals",
            _stats!['animals'] ?? 0,
          ),
          _featureItem(
            FontAwesomeIcons.cartFlatbed,
            "Orders",
            _stats!['orders'] ?? 0,
          ),
          _featureItem(
            FontAwesomeIcons.message,
            "Requests",
            _stats!['requests'] ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String label, int count) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportFooter() {
    return Center(
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Text(
            "For assistance, visit Help & Support from the menu.",
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
