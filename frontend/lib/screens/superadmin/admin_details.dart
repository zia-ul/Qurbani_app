import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminVerificationDetailsPage extends StatelessWidget {
  final String adminId;

  const AdminVerificationDetailsPage({
    super.key,
    required this.adminId,
  });

  static const Color primaryGreen = Color(0xff537D4F);


  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Verification Details'),
        backgroundColor: primaryGreen,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('adminVerifications')
            .doc(adminId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No verification data found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile('Name', data['name']),
              _infoTile('Email', data['email']),
              _infoTile('Phone', data['phone']),
              _infoTile('Address', data['address']),
              _infoTile('Government ID', data['governmentId']),
              _statusTile(data['status']),
              if (submittedAt != null)
                _infoTile(
                  'Submitted On',
                  DateFormat('dd MMM yyyy').format(submittedAt),
                ),
              const SizedBox(height: 20),
              _documentsSection(data['documentUrls']),
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
