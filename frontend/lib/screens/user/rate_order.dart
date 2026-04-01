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
  bool isSubmitting = false;
  bool submitted = false;
  String? loadErrorMessage;

  double adminRating = 0;
  final TextEditingController feedbackController = TextEditingController();

  String adminId = '';
  String adminName = '';

  String _displayMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadErrorMessage = null;
      });
    }

    try {
      data = await RatingService.getRatings(widget.orderId, widget.userId);

      submitted = data?['submitted'] ?? false;

      final order = data?['order'];
      final ratings = data?['ratings'] is Map
          ? Map<String, dynamic>.from(data?['ratings'] as Map)
          : <String, dynamic>{};

      if (order is Map) {
        adminId = (order['admin_id'] ?? '').toString();
        adminName = (order['admin_name'] ?? 'Admin').toString();

        final existingAdminRating = ratings[adminId]?['adminRating'];
        adminRating = existingAdminRating is num
            ? existingAdminRating.toDouble()
            : double.tryParse(existingAdminRating?.toString() ?? '') ?? 0;

        feedbackController.text = (ratings[adminId]?['feedback'] ?? '')
            .toString();
      }
    } catch (e) {
      final message = _displayMessage(e);
      ToastUtils.showError(message);

      if (mounted) {
        setState(() {
          loadErrorMessage = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> submitRatings() async {
    if (adminRating == 0) {
      ToastUtils.showError("Please rate the admin.");
      return;
    }

    if (adminId.isEmpty) {
      ToastUtils.showError(
        "We couldn't identify the admin for this order. Please try again later.",
      );
      return;
    }

    try {
      setState(() => isSubmitting = true);

      await RatingService.submitRatings(widget.orderId, widget.userId, [
        {
          'adminId': adminId,
          'adminRating': adminRating,
          'feedback': feedbackController.text.trim(),
        },
      ]);

      if (!mounted) return;

      setState(() => submitted = true);
      ToastUtils.showSuccess("Rating submitted successfully!");
    } catch (e) {
      ToastUtils.showError(_displayMessage(e));
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
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

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF4C7F53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Order #${widget.orderId}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Admin: $adminName",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              "Rate Admin",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 12),
            starRow(adminRating, (v) => setState(() => adminRating = v)),
            const SizedBox(height: 18),
            TextField(
              controller: feedbackController,
              enabled: !submitted,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Write feedback (optional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 22),
            if (!submitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitRatings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Submit Rating",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            if (submitted)
              const Text(
                "Thanks for your rating!",
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadErrorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F4),
        appBar: AppBar(
          title: const Text(
            "Rate Your Order",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  size: 44,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  loadErrorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Try Again"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      appBar: AppBar(
        title: const Text(
          "Rate Your Order",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [_headerCard(), const SizedBox(height: 16), _ratingCard()],
        ),
      ),
    );
  }
}
