import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/screens/superadmin/services/super_admin_services.dart';

class UserDetailsPage extends StatefulWidget {
  final String adminId;

  const UserDetailsPage({super.key, required this.adminId});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  late Future<List<dynamic>> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = Future.wait([
      SuperAdminService.getUserProfile(widget.adminId),
      SuperAdminService.getUserOrders(widget.adminId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final profile = snapshot.data![0] as Map<String, dynamic>;
          final orders =
              (snapshot.data![1] as List).cast<Map<String, dynamic>>();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserProfile(profile),
                const SizedBox(height: 16),
                _buildOrdersSection(orders),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= USER PROFILE =================

  Widget _buildUserProfile(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
            child: Text(
              (user['name'] != null && user['name'].isNotEmpty)
                  ? user['name'][0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                _getRoleBadge(user['role'] ?? 'user'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= ORDERS =================

  Widget _buildOrdersSection(List<Map<String, dynamic>> orders) {
    return _buildSectionCard(
      title: 'Orders Taken',
      icon: Icons.shopping_cart,
      children: orders.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('No orders found'),
              )
            ]
          : orders.map((order) {
              return ListTile(
                title: Text('Order #${order['id']}'),
                subtitle: Text(
                  'Status: ${order['status']}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  DateFormat('dd MMM yyyy')
                      .format(DateTime.parse(order['created_at'])),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
    );
  }

  // ================= COMMON UI =================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _getRoleBadge(String role) {
    Color color = role == 'admin'
        ? Colors.green
        : role == 'delivery'
            ? Colors.blue
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
