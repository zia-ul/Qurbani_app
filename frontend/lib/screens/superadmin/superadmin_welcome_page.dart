import 'package:flutter/material.dart';
import 'package:qurbani/screens/superadmin/services/super_admin_services.dart';
import 'package:qurbani/screens/superadmin/admin_details.dart';
import 'package:qurbani/screens/superadmin/superadmin_drawer.dart';

enum RoleFilter { all, user, admin, pending, delivery }

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  static const Color primaryGreen = Color(0xff537D4F);

  RoleFilter _selectedFilter = RoleFilter.all;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = _selectedFilter == RoleFilter.all ? 'all' : _selectedFilter.name;
      _users = await SuperAdminService.getUsers(role);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged(RoleFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Panel'),
        backgroundColor: primaryGreen,
        actions: [_filterDropdown()],
      ),
      drawer: SuperadminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final user = _users[i];
                        return _userCard(context, user['id'], user);
                      },
                    ),
    );
  }

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
          DropdownMenuItem(value: RoleFilter.pending, child: Text('Pending Admins')),
          DropdownMenuItem(value: RoleFilter.delivery, child: Text('Delivery Boys')),
        ],
        onChanged: (value) => _onFilterChanged(value!),
      ),
    );
  }

  Widget _userCard(BuildContext context, String userId, Map<String, dynamic> data) {
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
                          builder: (_) => AdminVerificationDetailsPage(adminId: userId),
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

  Future<void> _approveAdmin(BuildContext context, String adminId) async {
    try {
      await SuperAdminService.updateUser(adminId, 'approve');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin Approved')));
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
      try {
        await SuperAdminService.updateUser(adminId, 'reject');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Deleted')));
        _fetchUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}