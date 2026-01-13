import 'package:flutter/material.dart';
import 'package:qurbani/screens/superadmin/services/super_admin_services.dart'; 
import 'package:intl/intl.dart';

class AdminVerificationDetailsPage extends StatefulWidget {
  final String adminId;

  const AdminVerificationDetailsPage({
    super.key,
    required this.adminId,
  });

  static const Color primaryGreen = Color(0xff537D4F);

  @override
  State<AdminVerificationDetailsPage> createState() => _AdminVerificationDetailsPageState();
}

class _AdminVerificationDetailsPageState extends State<AdminVerificationDetailsPage> {
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
          final documents = data['documents'] as Map<String, dynamic>? ?? {};
          final status = data['status'] as String?;
          final submittedAt = data['created_at']; // Assuming backend returns this; adjust if not

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile('Name', documents['name']),
              _infoTile('Email', documents['email']),
              _infoTile('Phone', documents['phone']),
              _infoTile('Address', documents['address']),
              _infoTile('Government ID', documents['governmentId']),
              _statusTile(status),
              if (submittedAt != null)
                _infoTile(
                  'Submitted On',
                  DateFormat('dd MMM yyyy').format(DateTime.parse(submittedAt)),
                ),
              const SizedBox(height: 20),
              _documentsSection(documents['documentUrls']),
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
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        subtitle: Text(
          value?.toString() ?? 'N/A',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _statusTile(String? status) {
    Color color;

    switch (status) {
      case 'verified':
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        trailing: Icon(Icons.verified, color: color),
      ),
    );
  }

  Widget _documentsSection(dynamic urls) {
    if (urls == null || urls is! List || urls.isEmpty) {
      return const Text('No documents uploaded');
    }

    final List<String> documents = List<String>.from(urls);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submitted Documents',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...documents.map(
          (url) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}