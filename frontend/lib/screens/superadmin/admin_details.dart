/// This file contains the Admin Verification Details page, which displays
/// detailed information about an admin's verification status, including
/// organization details, documents, and review history.

import 'package:flutter/material.dart';
import 'package:Qurbani/screens/superadmin/services/super_admin_services.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/theme/theme.dart';

/// A page widget that displays detailed verification information for a specific admin.
class AdminVerificationDetailsPage extends StatefulWidget {
  /// The ID of the admin whose verification details are to be displayed.
  final String adminId;

  const AdminVerificationDetailsPage({super.key, required this.adminId});

  @override
  State<AdminVerificationDetailsPage> createState() =>
      _AdminVerificationDetailsPageState();
}

/// The state class for AdminVerificationDetailsPage, managing the verification data fetching and UI rendering.
class _AdminVerificationDetailsPageState
    extends State<AdminVerificationDetailsPage> {
  /// Future that holds the verification data fetched from the service.
  Future<Map<String, dynamic>>? _verificationFuture;

  @override
  void initState() {
    super.initState();
    _loadVerification();
  }

  /// Loads the verification data for the admin by calling the service.
  void _loadVerification() {
    setState(() {
      _verificationFuture = SuperAdminService.getVerification(widget.adminId);
    });
  }

  /// Builds the UI for the verification details page, including app bar and body with sections for status, organization details, documents, and review audit.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F4F6,
      ), // Light grey background from reference
      appBar: AppBar(
        title: const Text(
          'Verification Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _verificationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No verification data found'));
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(data['status']),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Organization Details',
                  icon: Icons.business,
                  children: [
                    _infoRow(
                      Icons.corporate_fare,
                      'Name',
                      data['organization_name'],
                    ),
                    _infoRow(Icons.phone, 'Phone', data['phone']),
                    _infoRow(Icons.history, 'Experience', data['experience']),
                    _infoRow(Icons.location_on, 'Address', data['address']),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Verification Documents',
                  icon: Icons.description,
                  children: [
                    _documentTile('Government ID', data['govt_id_url']),
                    _documentTile('Business Proof', data['business_proof_url']),
                    _documentTile('Bank Proof', data['bank_proof_url']),
                    _documentTile('Farm Photo', data['farm_photo_url']),
                  ],
                ),
                const SizedBox(height: 16),
                _buildReviewSection(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(String? status) {
    Color color = status == 'approved'
        ? Colors.green
        : (status == 'pending' ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(Icons.verified_user, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verification Status',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              Text(
                status?.toUpperCase() ?? 'PENDING',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (status == 'approved')
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

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
                Icon(icon, size: 20, color: AppTheme.primaryGreen),
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

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  value?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(String label, String? url) {
    return ListTile(
      leading: const Icon(Icons.file_present, color: Colors.grey),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: TextButton(
        onPressed: url == null
            ? null
            : () {
                /* Open URL */
              },
        child: const Text('VIEW'),
      ),
    );
  }

  Widget _buildReviewSection(Map<String, dynamic> data) {
    if (data['reviewed_by'] == null && data['review_note'] == null)
      return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Review Audit',
      icon: Icons.rate_review,
      children: [
        if (data['reviewed_by'] != null)
          _infoRow(Icons.person, 'Reviewed By', data['reviewed_by']),
        if (data['review_note'] != null)
          _infoRow(Icons.note, 'Note', data['review_note']),
        if (data['created_at'] != null)
          _infoRow(
            Icons.calendar_today,
            'Submitted On',
            DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(data['created_at'])),
          ),
      ],
    );
  }
}
