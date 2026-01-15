import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:qurbani/theme/theme.dart';
import 'package:qurbani/widgets/success_error_popup.dart';

class AdminSpecialRequestsPage extends StatefulWidget {
  const AdminSpecialRequestsPage({super.key});

  @override
  State<AdminSpecialRequestsPage> createState() =>
      _AdminSpecialRequestsPageState();
}

class _AdminSpecialRequestsPageState extends State<AdminSpecialRequestsPage> {
  String activeFilter = 'All';
  final Color scaffoldBg = const Color(0xFFF4F7F4);
  final _storage = const FlutterSecureStorage();
  static const _baseUrl = 'http://192.168.1.6:3000/api';

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw Exception('Not authenticated');

      final statusParam = activeFilter != 'All' ? '?status=$activeFilter' : '';
      final res = await http.get(
        Uri.parse('$_baseUrl/requests/admin$statusParam'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          requests = List<Map<String, dynamic>>.from(data['requests']);
        });
      } else {
        throw Exception(
          jsonDecode(res.body)['message'] ?? 'Failed to fetch requests',
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      activeFilter = filter;
    });
    _fetchRequests();
  }

  Future<void> _replyToRequest(Map<String, dynamic> request) async {
    final TextEditingController replyController = TextEditingController();
    if (request['reply_message'] != null) {
      replyController.text = request['reply_message'];
    }

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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () async {
              final reply = replyController.text.trim();
              if (reply.isEmpty) return;

              await _updateRequest(request['id'], 'reply', replyMessage: reply);
              Navigator.pop(dialogContext);
              _fetchRequests(); // Refresh
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

  Future<void> _closeRequest(String requestId) async {
    await _updateRequest(requestId, 'close');
    _fetchRequests(); // Refresh
  }

  Future<void> _updateRequest(
    String requestId,
    String action, {
    String? replyMessage,
  }) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) throw Exception('Not authenticated');

      final res = await http.put(
        Uri.parse('$_baseUrl/requests/admin/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': action, 'replyMessage': replyMessage}),
      );

      if (res.statusCode != 200) {
        throw Exception(jsonDecode(res.body)['message']);
      }
    } catch (e) {
      ToastUtils.showError("Error: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Replied':
        return Colors.blue;
      case 'Closed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      default:
        return AppTheme.primaryGreen;
    }
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
          // Filter Tabs
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
                    onSelected: (val) => _onFilterChanged(status),
                    selectedColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _getStatusColor(status)
                          : AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Request List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text('Error: $errorMessage'))
                : requests.isEmpty
                ? const Center(child: Text("No requests found."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final status = request['status'] ?? 'Pending';
                      final date = DateTime.tryParse(
                        request['created_at'] ?? '',
                      );

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
                            ListTile(
                              title: Text(
                                request['title'] ?? 'Urgent Request',
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
                                      color: AppTheme.primaryGreen,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    request['description'] ??
                                        'No instructions provided.',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 15),

                                  // User Info
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
                                          "Customer: ${request['user_name'] ?? 'User'}",
                                        ),
                                        _infoRow(
                                          Icons.confirmation_number,
                                          "Order ID: ${request['order_id'] ?? 'N/A'}",
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Admin Response
                                  if (request['reply_message'] != null) ...[
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
                                                color: AppTheme.primaryGreen,
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
                                            request['reply_message'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
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
                                                _replyToRequest(request),
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
                                              foregroundColor:
                                                  AppTheme.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _closeRequest(request['id']),
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
          Icon(icon, size: 14, color: AppTheme.primaryGreen),
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
