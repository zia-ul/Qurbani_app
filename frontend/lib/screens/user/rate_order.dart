import 'package:flutter/material.dart';
import 'package:Qurbani/services/ratings_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class RateOrderPage extends StatefulWidget {
  final String orderId;
  final String userId;

  const RateOrderPage({super.key, required this.orderId, required this.userId});

  @override
  State<RateOrderPage> createState() => _RateOrderPageState();
}

class _RateOrderPageState extends State<RateOrderPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  Map<String, double> adminRatings = {};
  Map<String, double> deliveryRatings = {};
  Map<String, TextEditingController> feedbackControllers = {};
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      data = await RatingService.getRatings(widget.orderId, widget.userId);
      submitted = data!['submitted'] ?? false;

      // Initialize ratings and controllers from fetched data
      final orders = data!['orders'] as List<dynamic>;
      final ratings = data!['ratings'] as Map<String, dynamic>;

      for (var order in orders) {
        final adminId = order['admin_id'];
        adminRatings[adminId] = (ratings[adminId]?['adminRating'] ?? 0)
            .toDouble();
        deliveryRatings[adminId] = (ratings[adminId]?['deliveryRating'] ?? 0)
            .toDouble();
        feedbackControllers[adminId] = TextEditingController(
          text: ratings[adminId]?['feedback'] ?? '',
        );
      }
    } catch (e) {
      ToastUtils.showError('Failed to load ratings: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> submitRatings() async {
    bool allRated = true;
    adminRatings.forEach((adminId, rating) {
      if (rating == 0 || (deliveryRatings[adminId] ?? 0) == 0) allRated = false;
    });

    if (!allRated) {
      ToastUtils.showError("Please rate all admins and deliveries.");
      return;
    }

    final ratingsList = adminRatings.keys
        .map(
          (adminId) => {
            'adminId': adminId,
            'adminRating': adminRatings[adminId],
            'deliveryRating': deliveryRatings[adminId],
            'feedback': feedbackControllers[adminId]?.text.trim() ?? '',
          },
        )
        .toList();

    try {
      await RatingService.submitRatings(
        widget.orderId,
        widget.userId,
        ratingsList,
      );
      setState(() => submitted = true);
      ToastUtils.showSuccess("Ratings submitted successfully!");
    } catch (e) {
      ToastUtils.showError("Failed to submit ratings: $e");
    }
  }

  Widget starRow(double value, Function(double) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < value ? Icons.star : Icons.star_border,
            color: AppTheme.primaryGreen,
            size: 32,
          ),
          onPressed: submitted ? null : () => onChanged(i + 1.0),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (data == null) {
      return const Scaffold(body: Center(child: Text("Failed to load data.")));
    }

    final orders = data!['orders'] as List<dynamic>;

    List<Widget> ratingCards = [];

    for (var order in orders) {
      final adminId = order['admin_id'];
      final adminName = order['admin_name'] ?? 'Unknown';
      final deliveryPersonName = order['delivery_person_name'] ?? 'Delivery';

      ratingCards.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (submitted) ...[
                  Text(
                    "Admin Rating: ${adminRatings[adminId]!.toStringAsFixed(1)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Delivery Rating: ${deliveryRatings[adminId]!.toStringAsFixed(1)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  "Admin: $adminName",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (!submitted) ...[
                  const SizedBox(height: 8),
                  const Text("⭐ Rate Admin"),
                  starRow(
                    adminRatings[adminId]!,
                    (v) => setState(() => adminRatings[adminId] = v),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  "Delivery: $deliveryPersonName",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (!submitted) ...[
                  const SizedBox(height: 8),
                  const Text("⭐ Rate Delivery"),
                  starRow(
                    deliveryRatings[adminId]!,
                    (v) => setState(() => deliveryRatings[adminId] = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: feedbackControllers[adminId],
                  maxLines: 2,
                  enabled: !submitted,
                  decoration: const InputDecoration(
                    hintText: "Feedback (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (submitted &&
                    (feedbackControllers[adminId]?.text.isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Feedback: ${feedbackControllers[adminId]?.text}",
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Your Order"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            ...ratingCards,
            const SizedBox(height: 16),
            if (!submitted)
              ElevatedButton(
                onPressed: submitRatings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text("Submit All Ratings"),
              ),
            if (submitted)
              const Text(
                "Thanks for your ratings!",
                style: TextStyle(color: AppTheme.primaryGreen, fontSize: 18),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
