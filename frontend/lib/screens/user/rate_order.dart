import 'package:flutter/material.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:Qurbani/services/ratings_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class RateOrderPage extends StatefulWidget {
  final String orderId;
  final String userId;
  final String? initialAdminId;
  final String? initialAdminName;

  const RateOrderPage({
    super.key,
    required this.orderId,
    required this.userId,
    this.initialAdminId,
    this.initialAdminName,
  });

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
    adminId = (widget.initialAdminId ?? '').trim();
    adminName = (widget.initialAdminName ?? 'Admin').trim();
    if (adminName.isEmpty) {
      adminName = 'Admin';
    }
    _fetchData();
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  String _firstNonEmptyValue(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return '';
    }

    for (final key in keys) {
      final normalized = (source[key] ?? '').toString().trim();
      if (normalized.isNotEmpty && normalized.toLowerCase() != 'null') {
        return normalized;
      }
    }

    return '';
  }

  void _applyAdminIdentity(
    Map<String, dynamic>? order,
    Map<String, dynamic> ratings,
  ) {
    final resolvedAdminId = _firstNonEmptyValue(order, ['admin_id', 'adminId']);
    final resolvedAdminName = _firstNonEmptyValue(order, [
      'admin_name',
      'adminName',
    ]);

    if (resolvedAdminId.isNotEmpty) {
      adminId = resolvedAdminId;
    }

    if (resolvedAdminName.isNotEmpty) {
      adminName = resolvedAdminName;
    }

    if (adminId.isEmpty) {
      for (final entry in ratings.entries) {
        if (entry.value is Map && entry.key.trim().isNotEmpty) {
          adminId = entry.key.trim();
          break;
        }
      }
    }

    if (adminName.isEmpty) {
      adminName = 'Admin';
    }
  }

  Future<void> _ensureAdminIdentity(Map<String, dynamic> ratings) async {
    if (adminId.isNotEmpty && adminName.isNotEmpty && adminName != 'Admin') {
      return;
    }

    try {
      final orderDetails = await OrderService.getOrderDetails(widget.orderId);
      _applyAdminIdentity(orderDetails, ratings);
    } catch (_) {
      if (adminName.isEmpty) {
        adminName = 'Admin';
      }
    }
  }

  Map<String, dynamic> _resolveExistingRating(Map<String, dynamic> ratings) {
    if (adminId.isNotEmpty && ratings[adminId] is Map) {
      return Map<String, dynamic>.from(ratings[adminId] as Map);
    }

    if (ratings['adminRating'] != null || ratings['feedback'] != null) {
      return Map<String, dynamic>.from(ratings);
    }

    for (final entry in ratings.entries) {
      if (entry.value is Map) {
        if (adminId.isEmpty && entry.key.trim().isNotEmpty) {
          adminId = entry.key.trim();
        }
        return Map<String, dynamic>.from(entry.value as Map);
      }
    }

    return <String, dynamic>{};
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
        _applyAdminIdentity(Map<String, dynamic>.from(order), ratings);
      }

      await _ensureAdminIdentity(ratings);

      final existingRating = _resolveExistingRating(ratings);
      final existingAdminRating = existingRating['adminRating'];
      adminRating = existingAdminRating is num
          ? existingAdminRating.toDouble()
          : double.tryParse(existingAdminRating?.toString() ?? '') ?? 0;

      feedbackController.text = (existingRating['feedback'] ?? '').toString();
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

    try {
      setState(() => isSubmitting = true);

      await _ensureAdminIdentity(const <String, dynamic>{});

      final ratingPayload = <String, dynamic>{
        'adminRating': adminRating,
        'feedback': feedbackController.text.trim(),
      };

      if (adminId.isNotEmpty) {
        ratingPayload['adminId'] = adminId;
      }

      await RatingService.submitRatings(widget.orderId, widget.userId, [
        ratingPayload,
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
