import 'package:flutter/material.dart';
import 'package:qurbani/screens/superadmin/services/super_admin_services.dart';
import 'package:intl/intl.dart';
import 'package:qurbani/theme/theme.dart';

class AdminVerificationDetailsPage extends StatefulWidget {
  final String adminId;

  const AdminVerificationDetailsPage({super.key, required this.adminId});

  static const Color primaryGreen = AppTheme.primaryGreen;

  @override
  State<AdminVerificationDetailsPage> createState() =>
      _AdminVerificationDetailsPageState();
}

class _AdminVerificationDetailsPageState
    extends State<AdminVerificationDetailsPage> {
  Future<Map<String, dynamic>>? _verificationFuture;

  @override
  void initState() {
    super.initState();
    _loadVerification();
  }

  void _loadVerification() {
    setState(() {
      _verificationFuture = SuperAdminService.getVerification(widget.adminId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Verification Details'),
        backgroundColor: AdminVerificationDetailsPage.primaryGreen,
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
          final status = data['status'] as String?;
          final submittedAt = data['created_at'] as String?;
          final reviewedBy = data['reviewed_by'] as String?;
          final reviewNote = data['review_note'] as String?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile('Organization Name', data['organization_name']),
              _infoTile('Phone', data['phone']),
              _infoTile('Experience', data['experience']),
              _infoTile('Address', data['address']),
              _infoTile('Government ID URL', data['govt_id_url']),
              _infoTile('Business Proof URL', data['business_proof_url']),
              _infoTile('Bank Proof URL', data['bank_proof_url']),
              _infoTile('Farm Photo URL', data['farm_photo_url']),
              _statusTile(status),
              if (submittedAt != null)
                _infoTile(
                  'Submitted On',
                  DateFormat('dd MMM yyyy').format(DateTime.parse(submittedAt)),
                ),
              if (reviewedBy != null) _infoTile('Reviewed By', reviewedBy),
              if (reviewNote != null) _infoTile('Review Note', reviewNote),
            ],
          );
        },
      ),
    );
  }

  /// ================= UI HELPERS =================

  Widget _infoTile(String title, dynamic value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        subtitle: Text(
          value?.toString() ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _statusTile(String? status) {
    Color color;

    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Card(
      child: ListTile(
        title: const Text(
          'Verification Status',
          style: TextStyle(fontSize: 12),
        ),
        subtitle: Text(
          status?.toUpperCase() ?? 'UNKNOWN',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        trailing: Icon(Icons.verified, color: color),
      ),
    );
  }
}
