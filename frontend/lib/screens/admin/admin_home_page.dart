
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:Qurbani/screens/admin/admin_share_setup.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/drawer.dart';
import 'package:Qurbani/screens/admin/admin_orders.dart';
import 'package:Qurbani/screens/admin/animal_listing.dart';
import 'package:Qurbani/screens/admin/special_requests_admin.dart';
import 'package:Qurbani/services/admin_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  static final String? _baseUrl = dotenv.env['BASE_URL'];

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
      // await AdminService.syncDeliveryRequests();

      // _startNotificationPolling();
      _startStatsPolling(); // Start live stats polling
      await _checkNotificationPermission();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _statsTimer?.cancel(); // Cancel stats timer
    super.dispose();
  }

  void _startStatsPolling() {
    _statsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _loadStats(); // reload stats from backend
    });
  }

  Future<void> _checkNotificationPermission() async {
    AppLogger.debug("Checking notification permission");

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      AppLogger.warning("Notification permission not granted. Requesting...");
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> _loadStats() async {
    try {
      AppLogger.debug("Fetching dashboard stats from backend");

      final stats =
          await AdminService.getDashboardStats(); // fetch from backend

      AppLogger.info("Dashboard stats loaded: $stats");

      setState(() {
        _stats = stats; // update UI
      });
    } catch (e, stack) {
      AppLogger.error("Failed to load dashboard stats", e, stack);
      // optional: show toast or ignore
    }
  }

  // ---------------------------------------------------------
  // PERMISSIONS
  // ---------------------------------------------------------

  Future<void> _checkPermissions() async {
    AppLogger.debug("Checking camera permission");
    final camStatus = await Permission.camera.request();
    AppLogger.debug("Camera permission: $camStatus");

    AppLogger.debug("Checking location permission");
    final locStatus = await Permission.location.request();
    AppLogger.debug("Location permission: $locStatus");

    AppLogger.debug("Checking notification permission");
    final notifAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!notifAllowed) {
      AppLogger.debug("Requesting notification permission");
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // ---------------------------------------------------------
  // BACKEND LOCATION CHECK (JWT BASED)
  // ---------------------------------------------------------

  Future<void> _ensureLocationSelected() async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      AppLogger.warning("No token found while checking admin location");
      return;
    }

    AppLogger.debug("Checking admin profile for location");

    final res = await http.get(
      Uri.parse("$_baseUrl/admin/profile"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      AppLogger.info("Admin profile loaded: city=${data['city']}");

      if (data['city'] == null) {
        AppLogger.warning("Admin has no city selected");
        // TODO: show location picker
      }
    } else {
      AppLogger.error("Failed to fetch admin profile", res.body);
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
                        // Expanded(
                        //   child: _buildActionCard(
                        //     title: "Add Animal",
                        //     subtitle: "List new animals",
                        //     icon: Icons.add_circle_outline,
                        //     color: const Color(0xff4CAF50),
                        //     onTap: () => Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (_) => const AddAnimalPage(),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        Expanded(
                          child: _buildActionCard(
                            title: "Shares Setup", // <-- Friendly name
                            subtitle: "Configure shares and pricing",
                            icon: Icons
                                .settings, // You can use a gear icon for settings
                            color: const Color(0xff4CAF50),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AdminShareSetupPage(), // <-- Your new page
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
        color: AppTheme.bgGradientEnd,
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
          color: AppTheme.bgGradientEnd,
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
