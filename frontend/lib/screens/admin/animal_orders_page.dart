import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/theme/theme.dart';

class AnimalOrdersPage extends StatefulWidget {
  final int animalId;
  final String animalName;

  const AnimalOrdersPage({
    super.key,
    required this.animalId,
    required this.animalName,
  });

  @override
  State<AnimalOrdersPage> createState() => _AnimalOrdersPageState();
}

class _AnimalOrdersPageState extends State<AnimalOrdersPage> {
  Future<List<Map<String, dynamic>>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _ordersFuture = OrderService.getAnimalOrders(widget.animalId.toString());
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return "Time not assigned";
    }

    try {
      final parsed =
          DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd MMM yyyy – hh:mm a')
          .format(parsed);
    } catch (e) {
      return "Invalid time format";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Orders for ${widget.animalName}"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            AppLogger.error(
              "Failed to load shareholders for animalId=${widget.animalId}",
              snapshot.error,
            );

            return Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Text(
                    "Something went wrong.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadData();
                      });
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                "No shareholders found for this animal.",
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
                  margin:
                      const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['shareholder_name'] ??
                              'No Name',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateTime(
                              order[
                                  'qurbani_datetime']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
