/// This file contains the Super Admin Dashboard screen, which allows super admins
/// to view and manage users, filter by roles, and approve or reject admin verifications.

import 'package:Qurbani/drawer.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/screens/superadmin/services/super_admin_services.dart';
import 'package:Qurbani/screens/superadmin/admin_details.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

enum AdminVerificationFilter { approved, notSubmitted, rejected }

/// The main dashboard widget for super admins to manage users and verifications.
class SuperAdminDashboard extends StatefulWidget {
  final String id;
  final String name;

  const SuperAdminDashboard({super.key, required this.id, required this.name});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  AdminVerificationFilter _selectedFilter =
      AdminVerificationFilter.notSubmitted;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFilter = AdminVerificationFilter.notSubmitted;
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const filterRole = 'admin';

      final users = await SuperAdminService.getUsers(filterRole);

      setState(() {
        _users = users.where((user) {
          final status = user['verification_status'] ?? 'not_submitted';

          switch (_selectedFilter) {
            case AdminVerificationFilter.approved:
              return status == 'approved';

            case AdminVerificationFilter.rejected:
              return status == 'rejected';

            case AdminVerificationFilter.notSubmitted:
              return status == 'not_submitted' ||
                  status == null ||
                  status == '';
          }
        }).toList();
      });
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
            ),
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
      _fetchUsers(); 
    } catch (e) {
      ToastUtils.showError('Failed to reject admin');
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        AdminVerificationFilter tempFilter = _selectedFilter;

        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.25,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: AppTheme.bgGradientEnd,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      const Text(
                        'Filter Admins By Verification Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...AdminVerificationFilter.values.map((filter) {
                        String label;
                        switch (filter) {
                          case AdminVerificationFilter.approved:
                            label = "APPROVED";
                            break;
                          case AdminVerificationFilter.rejected:
                            label = "REJECTED";
                            break;
                          case AdminVerificationFilter.notSubmitted:
                            label = "NOT SUBMITTED";
                            break;
                        }

                        return RadioListTile<AdminVerificationFilter>(
                          value: filter,
                          groupValue: tempFilter,
                          activeColor: AppTheme.primaryGreen,
                          title: Text(label),
                          onChanged: (val) =>
                              setModalState(() => tempFilter = val!),
                        );
                      }).toList(),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(
                                  () => _selectedFilter =
                                      AdminVerificationFilter.notSubmitted,
                                );
                                _fetchUsers();
                                Navigator.pop(context);
                              },
                              child: const Text('RESET'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                              ),
                              onPressed: () {
                                setState(() => _selectedFilter = tempFilter);
                                _fetchUsers();
                                Navigator.pop(context);
                              },
                              child: const Text('APPLY'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
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
            color: AppTheme.bgGradientEnd,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.bgGradientEnd),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      drawer: MasterDrawer(
        name: widget.name,
        id: widget.id,
        role: 'super_admin',
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          const SizedBox(height: 4),

          _verificationFilterBar(),

          const SizedBox(height: 8),
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
        color: AppTheme.bgGradientEnd,
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

  Widget _verificationFilterBar() {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: AdminVerificationFilter.values.map((filter) {
          final bool isSelected = _selectedFilter == filter;

          String label;
          switch (filter) {
            case AdminVerificationFilter.approved:
              label = "APPROVED";
              break;
            case AdminVerificationFilter.rejected:
              label = "REJECTED";
              break;
            case AdminVerificationFilter.notSubmitted:
              label = "NOT SUBMITTED";
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade700,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
              backgroundColor: AppTheme.bgGradientEnd,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade300,
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
                _fetchUsers();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Mimics the "Shareholder List" item style
  Widget _userListItem(Map<String, dynamic> data) {
    final String role = data['role'] ?? 'user';
    final String userId = data['id'];
    final String verificationStatus =
        data['verification_status'] ?? 'not_submitted';

    final bool canApprove =
        verificationStatus == 'pending' ||
        verificationStatus == 'not_submitted';

    final bool canReject = verificationStatus != 'rejected';

    // (role == 'admin' || role == 'delivery') && verificationStatus == 'pending';
    final bool isVerifiedAdmin =
        role == 'admin' && verificationStatus == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data['name'] ?? 'No Name',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isVerifiedAdmin)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 18,
                          ),
                      ],
                    ),

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
                onPressed: () {
                  if (role == 'admin') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminVerificationDetailsPage(adminId: userId),
                      ),
                    );
                  } 
                },
              ),
            ],
          ),
          // if (needsApproval) ...[
          //   const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canApprove)
                _actionButton(
                  label: 'APPROVE',
                  color: Colors.green,
                  onTap: () => _approveAdmin(context, userId),
                ),

              const SizedBox(width: 8),

              if (canReject)
                _actionButton(
                  label: 'REJECT',
                  color: AppTheme.warningRed,
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
    // if (role == 'delivery') color = Colors.blue;

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
          foregroundColor: AppTheme.bgGradientEnd,
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
}
