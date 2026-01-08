import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';

class AdminSpecialRequestsPage extends StatefulWidget {
  const AdminSpecialRequestsPage({super.key});

  @override
  State<AdminSpecialRequestsPage> createState() =>
      _AdminSpecialRequestsPageState();
}

class _AdminSpecialRequestsPageState extends State<AdminSpecialRequestsPage> {
  String activeFilter = 'All'; // 'Pending', 'Replied', 'Closed'
  final Color primaryGreen = const Color(0xFF3D6B4E);
  final Color scaffoldBg = const Color(0xFFF4F7F4);

  // Helper to get status color for badges
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Replied':
        return Colors.blue;
      case 'Closed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      default:
        return Color(0xff537D4F);
    }
  }

  Future<void> _replyToRequest(
    BuildContext context,
    DocumentSnapshot requestDoc,
  ) async {
    final TextEditingController replyController = TextEditingController();
    final data = requestDoc.data() as Map<String, dynamic>;
    final userId = data['userId'];

    // Pre-fill if editing an existing reply
    if (data['replyMessage'] != null) {
      replyController.text = data['replyMessage'];
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final userEmail = userData['email'] ?? "";
    final userName = userData['name'] ?? "Customer";

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Respond to Request'),
        content: TextField(
          controller: replyController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Type your message...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () async {
              final reply = replyController.text.trim();
              if (reply.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('requests')
                  .doc(requestDoc.id)
                  .update({
                    'replyMessage': reply,
                    'status': 'Replied',
                    'repliedAt': FieldValue.serverTimestamp(),
                  });

              final Email email = Email(
                body:
                    "Hello $userName,\n\nRegarding: ${data['title']}\nAdmin reply: $reply",
                subject: "Update on Special Request",
                recipients: [userEmail],
              );

              try {
                await FlutterEmailSender.send(email);
              } catch (e) {
                debugPrint("Email failed: $e");
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(
              'Send Reply',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeRequest(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('requests').doc(docId).update({
      'status': 'Closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          "Special Requests",
          style: TextStyle(
            color: Color(0xFF2D4F32),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D4F32)),
      ),
      body: Column(
        children: [
          // 1. FILTER TABS
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['All', 'Pending', 'Replied', 'Closed'].map((status) {
                bool isSelected = activeFilter == status;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (val) => setState(() => activeFilter = status),
                    selectedColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _getStatusColor(status)
                          : Color(0xff537D4F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 2. REQUEST LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No requests found."));
                }

                var docs = snapshot.data!.docs;
                if (activeFilter != 'All') {
                  docs = docs
                      .where((d) => (d.data() as Map)['status'] == activeFilter)
                      .toList();
                }

                if (docs.isEmpty)
                  return const Center(
                    child: Text("No requests found for this filter."),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'Pending';
                    final date = (data['createdAt'] as Timestamp?)?.toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header
                          ListTile(
                            title: Text(
                              data['title'] ?? 'Urgent Request',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(date ?? DateTime.now()),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Request Details:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff537D4F),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['description'] ??
                                      'No instructions provided.',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 15),

                                // User Info Box
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      _infoRow(
                                        Icons.person,
                                        "Customer: ${data['userName'] ?? 'User'}",
                                      ),
                                      _infoRow(
                                        Icons.confirmation_number,
                                        "Order ID: ${data['orderId'] ?? 'N/A'}",
                                      ),
                                    ],
                                  ),
                                ),

                                // Admin Response (if exists)
                                if (data['replyMessage'] != null) ...[
                                  const SizedBox(height: 15),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: primaryGreen,
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              "Confirmed Response",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['replyMessage'],
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Action Buttons
                                if (status != 'Closed') ...[
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _replyToRequest(context, doc),
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 16,
                                          ),
                                          label: Text(
                                            status == 'Replied'
                                                ? "Edit Reply"
                                                : "Reply",
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryGreen,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _closeRequest(context, doc.id),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          label: const Text("Close"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade400,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Color(0xff537D4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
