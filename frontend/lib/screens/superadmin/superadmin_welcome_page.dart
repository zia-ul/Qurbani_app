import 'package:flutter/material.dart';
import 'package:Qurbani/screens/superadmin/services/super_admin_services.dart';
import 'package:Qurbani/screens/superadmin/admin_details.dart';
import 'package:Qurbani/screens/superadmin/superadmin_drawer.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

enum RoleFilter { all, user, admin, delivery }

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
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
      final filterRole = _selectedFilter == RoleFilter.all
          ? 'all'
          : _selectedFilter.name;
      _users = await SuperAdminService.getUsers(filterRole);
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

  Future<void> _approveAdmin(BuildContext context, String adminId) async {
    try {
      await SuperAdminService.updateUser(
        adminId,
        'approve',
        reviewNote: 'Documents verified and approved',
      );

      ToastUtils.showSuccess('Admin approved successfully');
      _fetchUsers(); // refresh list
    } catch (e) {
      ToastUtils.showError('Failed to approve admin');
    }
  }

  Future<void> _deleteAdmin(BuildContext context, String adminId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Admin'),
        content: const Text(
          'Are you sure you want to reject this admin verification?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SuperAdminService.updateUser(
        adminId,
        'reject',
        reviewNote: 'Verification documents not acceptable',
      );

      ToastUtils.showSuccess('Admin rejected');
      _fetchUsers(); // refresh list
    } catch (e) {
      ToastUtils.showError('Failed to reject admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F4F6,
      ), // Light grey background like reference
      appBar: AppBar(
        title: const Text(
          'Super Admin Panel',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [_filterDropdown()],
      ),
      drawer: const SuperadminDrawer(),
      body: Column(
        children: [
          _buildSummaryHeader(), // Added a summary header similar to "Order Summary"
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage'))
                : _users.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _userListItem(_users[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // Mimics the "Order Summary" header from the reference
  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.supervised_user_circle,
            color: AppTheme.primaryGreen,
            size: 30,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Management Overview",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "Total Records: ${_users.length}",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  // Mimics the "Shareholder List" item style
  Widget _userListItem(Map<String, dynamic> data) {
    final String role = data['role'] ?? 'user';
    final String userId = data['id'];
    final String verificationStatus =
        data['verification_status'] ?? 'not_submitted';

    final bool needsApproval =
        role == 'admin' && verificationStatus == 'pending';
    // (role == 'admin' || role == 'delivery') && verificationStatus == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Text(
                  data['name']?[0] ?? 'U',
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data['email'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _getRoleBadge(role),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminVerificationDetailsPage(adminId: userId),
                  ),
                ),
              ),
            ],
          ),
          // if (needsApproval) ...[
          //   const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (needsApproval) ...[
                const Divider(height: 24),
                _actionButton(
                  label: 'APPROVE',
                  color: Colors.green,
                  onTap: () => _approveAdmin(context, userId),
                ),
              ],
              const SizedBox(width: 8),

              _actionButton(
                label: 'REJECT',
                color: Colors.red.shade400,
                onTap: () => _deleteAdmin(context, userId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getRoleBadge(String role) {
    Color color = Colors.grey;
    if (role == 'admin') color = Colors.green;
    if (role == 'delivery') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
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
        items: RoleFilter.values.map((filter) {
          return DropdownMenuItem(
            value: filter,
            child: Text(
              filter.name.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedFilter = value);
            _fetchUsers();
          }
        },
      ),
    );
  }
}
