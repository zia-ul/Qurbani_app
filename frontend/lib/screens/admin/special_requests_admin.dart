import 'dart:convert';

import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

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
      if (token == null) {
        throw const ApiException('Not authenticated');
      }

      final queryParameters = activeFilter == 'All'
          ? null
          : <String, dynamic>{'status': activeFilter};

      final res = await ApiClient.get(
        ApiClient.uri('requests/admin', queryParameters: queryParameters),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw ApiException(
          ApiClient.errorMessage(
            res,
            fallbackMessage: 'Unable to load special requests right now.',
          ),
          statusCode: res.statusCode,
        );
      }

      final data = ApiClient.decodeMap(
        res,
        fallbackMessage: 'Unable to load special requests right now.',
      );

      AppLogger.info(
        "Special requests loaded | count=${data['requests']?.length ?? 0}",
      );

      if (!mounted) return;
      setState(() {
        requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
      });
    } catch (e, stack) {
      AppLogger.error("Failed to fetch special requests", e, stack);
      if (!mounted) return;
      setState(() {
        errorMessage = _friendlyErrorMessage(
          e,
          fallback: 'Unable to load special requests right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      activeFilter = filter;
    });
    _fetchRequests();
  }

  String _mapRequestStatus(dynamic status) {
    final normalized = status?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case '0':
      case 'pending':
        return 'Pending';
      case '1':
      case 'replied':
        return 'Replied';
      case '2':
      case 'closed':
        return 'Closed';
      default:
        return 'Pending';
    }
  }

  Future<void> _replyToRequest(Map<String, dynamic> request) async {
    final replyController = TextEditingController(
      text: request['reply_message']?.toString() ?? '',
    );

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

              final wasUpdated = await _updateRequest(
                request['id'].toString(),
                'reply',
                replyMessage: reply,
              );

              if (!mounted || !dialogContext.mounted || !wasUpdated) return;
              Navigator.pop(dialogContext);
              _fetchRequests();
            },
            child: const Text(
              'Send Reply',
              style: TextStyle(color: AppTheme.bgGradientEnd),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeRequest(String requestId) async {
    AppLogger.warning("Closing request | requestId=$requestId");
    final wasUpdated = await _updateRequest(requestId, 'close');
    if (wasUpdated) {
      _fetchRequests();
    }
  }

  Future<bool> _updateRequest(
    String requestId,
    String action, {
    String? replyMessage,
  }) async {
    AppLogger.debug("Updating request | id=$requestId | action=$action");

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw const ApiException('Not authenticated');
      }

      final res = await ApiClient.put(
        ApiClient.uri('requests/admin/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': action,
          'replyMessage': replyMessage,
        }),
      );

      if (res.statusCode != 200) {
        throw ApiException(
          ApiClient.errorMessage(
            res,
            fallbackMessage: 'Unable to update the special request right now.',
          ),
          statusCode: res.statusCode,
        );
      }

      return true;
    } catch (e, stack) {
      AppLogger.error("Failed to update special request", e, stack);
      ToastUtils.showError(
        _friendlyErrorMessage(
          e,
          fallback: "Unable to update the special request right now.",
        ),
      );
      return false;
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

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _emptyStateMessage() {
    if (activeFilter == 'All') {
      return "No special requests yet.";
    }

    return "No ${activeFilter.toLowerCase()} requests found.";
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
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D4F32)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['All', 'Pending', 'Replied', 'Closed'].map((status) {
                final isSelected = activeFilter == status;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) => _onFilterChanged(status),
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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchRequests,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: AppTheme.bgGradientEnd,
                                ),
                                child: const Text("Try Again"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : requests.isEmpty
                        ? Center(child: Text(_emptyStateMessage()))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              final requestId = request['id']?.toString() ?? '';
                              final status = _mapRequestStatus(request['status']);
                              final createdAtRaw = request['created_at'];
                              final date =
                                  DateTime.tryParse(createdAtRaw?.toString() ?? '');
                              final title =
                                  request['title']?.toString() ?? 'Urgent Request';
                              final description = request['description']
                                      ?.toString() ??
                                  'No instructions provided.';
                              final userName =
                                  request['user_name']?.toString() ?? 'User';
                              final orderId =
                                  request['order_id']?.toString() ?? 'N/A';
                              final replyMessage =
                                  request['reply_message']?.toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgGradientEnd,
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
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd MMM yyyy, hh:mm a')
                                            .format(date ?? DateTime.now()),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status,
                                          style: const TextStyle(
                                            color: AppTheme.bgGradientEnd,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            description,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 15),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                _infoRow(
                                                  Icons.person,
                                                  "Customer: $userName",
                                                ),
                                                _infoRow(
                                                  Icons.confirmation_number,
                                                  "Order ID: $orderId",
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (replyMessage != null &&
                                              replyMessage.isNotEmpty) ...[
                                            const SizedBox(height: 15),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                        color:
                                                            AppTheme.primaryGreen,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      const Text(
                                                        "Confirmed Response",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    replyMessage,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          AppTheme.primaryGreen,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _closeRequest(requestId),
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 16,
                                                    ),
                                                    label:
                                                        const Text("Close"),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppTheme.warningRed,
                                                      foregroundColor:
                                                          AppTheme.bgGradientEnd,
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
