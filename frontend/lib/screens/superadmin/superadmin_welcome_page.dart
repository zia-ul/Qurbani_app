import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/superadmin/admin_details.dart';
import 'package:qurbani/screens/superadmin/superadmin_drawer.dart';

enum RoleFilter { all, user, admin, pending }

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  static const Color primaryGreen = Color(0xff537D4F);

  RoleFilter _selectedFilter = RoleFilter.all;

  /// ================= FIRESTORE QUERY =================
  Stream<QuerySnapshot> get _usersStream {
    final usersRef = FirebaseFirestore.instance.collection('users');

    switch (_selectedFilter) {
      case RoleFilter.user:
        return usersRef
            .where('role', isEqualTo: 'user')
            .orderBy('createdAt', descending: true)
            .snapshots();

      case RoleFilter.admin:
        return usersRef
            .where('role', isEqualTo: 'admin')
            .orderBy('createdAt', descending: true)
            .snapshots();

      case RoleFilter.pending:
        return usersRef
            .where('role', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots();

      case RoleFilter.all:
      default:
        return usersRef
            .where('role', whereIn: ['admin', 'pending', 'user'])
            .orderBy('createdAt', descending: true)
            .snapshots();
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Panel'),
        backgroundColor: primaryGreen,
        actions: [_filterDropdown()],
      ),
      drawer: SuperadminDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final doc = users[i];
              final data = doc.data() as Map<String, dynamic>;
              return _userCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  /// ================= FILTER DROPDOWN =================
  Widget _filterDropdown() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: DropdownButton<RoleFilter>(
        value: _selectedFilter,
        dropdownColor: Colors.white,
        underline: const SizedBox(),
        icon: const Icon(Icons.filter_list, color: Colors.white),
        items: const [
          DropdownMenuItem(value: RoleFilter.all, child: Text('All')),
          DropdownMenuItem(value: RoleFilter.user, child: Text('Users')),
          DropdownMenuItem(value: RoleFilter.admin, child: Text('Admins')),
          DropdownMenuItem(
            value: RoleFilter.pending,
            child: Text('Pending Admins'),
          ),
        ],
        onChanged: (value) {
          setState(() => _selectedFilter = value!);
        },
      ),
    );
  }

  /// ================= USER CARD =================
  Widget _userCard(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
  ) {
    final role = data['role'];

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(data['email'] ?? ''),
                    ],
                  ),
                ),
                if (role != 'user')
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminVerificationDetailsPage(adminId: userId),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(role.toUpperCase()),
              backgroundColor: role == 'pending'
                  ? Colors.orange[100]
                  : role == 'admin'
                  ? Colors.green[100]
                  : Colors.blue[100],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (role == 'pending')
                  _actionButton(
                    label: 'Approve',
                    color: Colors.green,
                    onTap: () => _approveAdmin(context, userId),
                  ),
                if (role != 'user')
                  _actionButton(
                    label: 'Reject',
                    color: Colors.red,
                    onTap: () => _deleteAdmin(context, userId),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ================= ACTION BUTTON =================
  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// ================= ACTIONS =================
  Future<void> _approveAdmin(BuildContext context, String adminId) async {
    await FirebaseFirestore.instance.collection('users').doc(adminId).update({
      'role': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('adminVerifications')
        .doc(adminId)
        .update({'status': 'verified'});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Admin Approved')));
  }

  Future<void> _deleteAdmin(BuildContext context, String adminId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .delete();
    }
  }
}
