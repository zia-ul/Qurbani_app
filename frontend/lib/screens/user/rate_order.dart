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
  bool submitted = false;

  double adminRating = 0;
  double deliveryRating = 0;
  final TextEditingController feedbackController = TextEditingController();

  String adminId = '';
  String adminName = '';
  String deliveryPersonName = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      data = await RatingService.getRatings(widget.orderId, widget.userId);

      submitted = data?['submitted'] ?? false;

      final order = data?['order'];
      final ratings = data?['ratings'] ?? {};

      if (order != null) {
        adminId = order['admin_id'];
        adminName = order['admin_name'] ?? 'Admin';
        deliveryPersonName = order['delivery_person_name'] ?? 'Delivery';

        adminRating = (ratings['adminRating'] ?? 0).toDouble();
        deliveryRating = (ratings['deliveryRating'] ?? 0).toDouble();

        feedbackController.text = ratings['feedback'] ?? '';
      }
    } catch (e) {
      ToastUtils.showError("Failed to load ratings: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> submitRatings() async {
    if (adminRating == 0 || deliveryRating == 0) {
      ToastUtils.showError("Please rate both admin and delivery.");
      return;
    }

    try {
      await RatingService.submitRatings(widget.orderId, widget.userId, [
        {
          'adminId': adminId,
          'adminRating': adminRating,
          'deliveryRating': deliveryRating,
          'feedback': feedbackController.text.trim(),
        },
      ]);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Your Order"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Admin: $adminName",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                const Text("Rate Admin"),
                starRow(adminRating, (v) => setState(() => adminRating = v)),

                const SizedBox(height: 16),

                Text(
                  "Delivery: $deliveryPersonName",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                const Text("Rate Delivery"),
                starRow(
                  deliveryRating,
                  (v) => setState(() => deliveryRating = v),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: feedbackController,
                  enabled: !submitted,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: "Feedback (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

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
                    child: const Text("Submit Rating"),
                  ),

                if (submitted)
                  const Text(
                    "Thanks for your rating!",
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
