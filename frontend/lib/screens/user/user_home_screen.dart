import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Qurbani/drawer.dart';
import 'package:Qurbani/screens/user/marketplace.dart';
import 'package:Qurbani/screens/user/booked_page.dart';
import 'package:Qurbani/screens/user/currency_notifier.dart';
import 'package:Qurbani/theme/theme.dart';

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
  final Color bgGradientStart = const Color(0xffF2E8D5); // Parchment style
  final Color bgGradientEnd = const Color(0xffFFFFFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _checkPermissions();
    });
    // Notification Listeners
    // _listenForStatusUpdates();
  }

  // --- Notification Logic ---
  // Consolidated listener to handle both processing and delivery updates efficiently
  // void _listenForStatusUpdates() {
  //   FirebaseFirestore.instance
  //       .collection('admin_orders')
  //       .where('userId', isEqualTo: widget.id)
  //       .snapshots()
  //       .listen((snapshot) {
  //         for (var docChange in snapshot.docChanges) {
  //           if (docChange.type == DocumentChangeType.modified) {
  //             final data = docChange.doc.data();
  //             if (data == null) continue;

  //             final orderId = docChange.doc.id;

  //             // 1. Check Processing Status Change
  //             final bool procNotified = data['userProcessingNotified'] ?? false;
  //             final String procStatus = data['processingStatus'] ?? '';
  //             if (procStatus.isNotEmpty && !procNotified) {
  //               _triggerNotification(
  //                 id: 100,
  //                 title: '⚙️ Order Processing',
  //                 body: 'Order #$orderId status: "$procStatus"',
  //               );
  //               _markAsNotified(docChange.doc.id, 'userProcessingNotified');
  //             }

  //             // 2. Check Delivery Status Change
  //             final bool delNotified = data['userDeliveryNotified'] ?? false;
  //             final String delStatus = data['deliveryStatus'] ?? '';
  //             if (delStatus.isNotEmpty && !delNotified) {
  //               _triggerNotification(
  //                 id: 200,
  //                 title: '🚚 Delivery Update',
  //                 body: 'Order #$orderId delivery: "$delStatus"',
  //               );
  //               _markAsNotified(docChange.doc.id, 'userDeliveryNotified');
  //             }
  //           }
  //         }
  //       });
  // }

  // void _triggerNotification({
  //   required int id,
  //   required String title,
  //   required String body,
  // }) {
  //   AwesomeNotifications().createNotification(
  //     content: NotificationContent(
  //       id: id + DateTime.now().millisecond,
  //       channelKey: 'user_orders',
  //       title: title,
  //       body: body,
  //       notificationLayout: NotificationLayout.Default,
  //     ),
  //   );
  // }

  // void _markAsNotified(String docId, String field) {
  //   FirebaseFirestore.instance
  //       .collection('admin_orders')
  //       .doc(docId)
  //       .update({field: true})
  //       .catchError((e) => print("Notification flag update failed: $e"));
  // }

  // Future<void> _checkPermissions() async {
  //   await [Permission.notification, Permission.location].request();

  //   bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  //   if (!isAllowed) {
  //     AwesomeNotifications().requestPermissionToSendNotifications();
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MasterDrawer(name: widget.name, id: widget.id, role: widget.role),
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
                            subtitle: "Explore & book animals",
                            icon: Icons.storefront,
                            color: const Color(0xff4CAF50),
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
                            title: "My Bookings",
                            subtitle: "Track your orders",
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
