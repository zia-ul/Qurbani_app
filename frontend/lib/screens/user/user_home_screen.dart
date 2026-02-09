import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/drawer.dart';
import 'package:Qurbani/screens/user/marketplace.dart';
import 'package:Qurbani/screens/user/booked_page.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  final String id;
  final String name;
  final String role;

  const HomePage({
    super.key,
    required this.id,
    required this.name,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
    // Notification Listeners
    // _listenForStatusUpdates();
  }


  Future<void> _checkPermissions() async {
    await [Permission.notification, Permission.location].request();

    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MasterDrawer(name: widget.name, id: widget.id, role: widget.role),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.bgGradientStart, AppTheme.bgGradientEnd],
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
              // title: Text("QURBANI MARKETPLACE",
              //   style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
              // actions: [
              //   CartBadge(userId: widget.id),
              //   const SizedBox(width: 15),
              // ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Assalamu Alaikum,",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.primaryGreen,
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
                      "Track your Qurbani orders and status in real time.",
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 25),

                    // FEATURE BAR
                    _buildFeatureBanner(),
                    const SizedBox(height: 30),

                    // MAIN ACTION CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            title: "Marketplace",
                            subtitle: "Choose and book your Qurbani animal",
                            icon: Icons.storefront,
                            color: AppTheme.primaryGreen,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                // builder: (_) => const AnimalGridPage(),
                                builder: (_) => const AdminDirectoryPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildActionCard(
                            title: "My Qurbani",
                            subtitle: "View animal details and track delivery",
                            icon: Icons.assignment_turned_in_outlined,
                            color: const Color(0xff2196F3),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookedPage(userId: widget.id),
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
          _featureItem(Icons.verified_user_outlined, "Healthy"),
          _featureItem(Icons.local_shipping_outlined, "Live Track"),
          _featureItem(Icons.payments_outlined, "Secure"),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(height: 4),
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
        height: 160,
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
