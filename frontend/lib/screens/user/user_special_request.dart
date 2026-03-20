import 'package:flutter/material.dart';
import 'package:Qurbani/services/request_service.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/theme/theme.dart';

class MySpecialRequestsPage extends StatefulWidget {
  const MySpecialRequestsPage({super.key});

  @override
  State<MySpecialRequestsPage> createState() => _MySpecialRequestsPageState();
}

class _MySpecialRequestsPageState extends State<MySpecialRequestsPage> {
  Future<List<Map<String, dynamic>>>? _requestsFuture;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  void _fetchRequests() {
    setState(() {
      _requestsFuture = RequestService.getUserRequests();
    });
  }

  String _mapRequestStatus(dynamic status) {
    final intStatus = int.tryParse(status?.toString() ?? '') ?? 0;

    switch (intStatus) {
      case 0:
        return 'Pending';
      case 1:
        return 'Replied';
      case 2:
        return 'Closed';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'replied':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return AppTheme.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Special Requests"),
        backgroundColor: AppTheme.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: _fetchRequests,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Text("No special requests created yet."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              final status = _mapRequestStatus(request['status']);
              final createdAt = DateTime.tryParse(
                request['created_at']?.toString() ?? '',
              );
              final repliedAt = DateTime.tryParse(
                request['replied_at']?.toString() ?? '',
              );

              final title = request['title']?.toString() ?? "Request";
              final description =
                  request['description']?.toString() ??
                  "No description provided";
              final replyMessage = request['reply_message']?.toString();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.bgGradientEnd,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        description,
                        style: const TextStyle(fontSize: 15),
                      ),

                      const SizedBox(height: 10),

                      if (createdAt != null)
                        Text(
                          "Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryGreen,
                          ),
                        ),

                      if (replyMessage != null) ...[
                        const Divider(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Admin Response:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                replyMessage,
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (repliedAt != null)
                                Text(
                                  "Replied: ${DateFormat('dd MMM yyyy, hh:mm a').format(repliedAt)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}