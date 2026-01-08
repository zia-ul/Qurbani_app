import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RateOrderPage extends StatefulWidget {
  final String orderId;
  final String userId;

  const RateOrderPage({super.key, required this.orderId, required this.userId});

  @override
  State<RateOrderPage> createState() => _RateOrderPageState();
}

class _RateOrderPageState extends State<RateOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, double> adminRatings = {};
  Map<String, double> deliveryRatings = {};
  Map<String, TextEditingController> feedbackControllers = {};
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    fetchExistingRatings();
  }

  // Fetch existing ratings if already submitted
  Future<void> fetchExistingRatings() async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('orderId', isEqualTo: widget.orderId)
        .where('userId', isEqualTo: widget.userId)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final adminId = data['adminId'] ?? 'unknown';
      adminRatings[adminId] = (data['adminRating'] ?? 0).toDouble();
      deliveryRatings[adminId] = (data['deliveryRating'] ?? 0).toDouble();
      feedbackControllers[adminId] = TextEditingController(
        text: data['feedback'] ?? '',
      );
    }

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        submitted = true; // Already rated
      });
    }
  }

  Future<void> submitRatings() async {
    bool allRated = true;

    adminRatings.forEach((adminId, rating) {
      if (rating == 0 || deliveryRatings[adminId] == 0) allRated = false;
    });

    if (!allRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please rate all admins and deliveries.")),
      );
      return;
    }

    for (var adminId in adminRatings.keys) {
      final docId = "${widget.orderId}_${widget.userId}_$adminId";

      await _firestore.collection('ratings').doc(docId).set({
        "orderId": widget.orderId,
        "userId": widget.userId,
        "adminId": adminId,
        "adminRating": adminRatings[adminId],
        "deliveryRating": deliveryRatings[adminId],
        "feedback": feedbackControllers[adminId]?.text.trim() ?? '',
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    setState(() => submitted = true);
  }

  // Widget to display stars
  Widget starRow(double value, Function(double) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < value ? Icons.star : Icons.star_border,
            color: Color(0xff537D4F),
            size: 32,
          ),
          onPressed: submitted ? null : () => onChanged(i + 1),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Your Order"),
        backgroundColor: Color(0xff537D4F),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('admin_orders')
            .where('orderId', isEqualTo: widget.orderId)
            .where('userId', isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final adminOrders = snapshot.data!.docs;
          if (adminOrders.isEmpty) {
            return const Center(child: Text("No delivery information found."));
          }

          List<Widget> ratingCards = [];

          for (var adminOrder in adminOrders) {
            final aData = adminOrder.data() as Map<String, dynamic>;
            final adminId = aData['adminId'] ?? 'unknown';
            final adminName = aData['adminName'] ?? 'Unknown';
            final deliveryPersonName =
                aData['deliveryPersonName'] ?? 'Delivery';

            adminRatings.putIfAbsent(adminId, () => 0);
            deliveryRatings.putIfAbsent(adminId, () => 0);
            feedbackControllers.putIfAbsent(
              adminId,
              () => TextEditingController(),
            );

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
                      // Show numeric ratings
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

                      // Feedback
                      TextField(
                        controller: feedbackControllers[adminId],
                        maxLines: 2,
                        enabled: !submitted,
                        decoration: const InputDecoration(
                          hintText: "Feedback (optional)",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      // Show feedback read-only after submission
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

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                ...ratingCards,
                const SizedBox(height: 16),
                if (!submitted)
                  ElevatedButton(
                    onPressed: submitRatings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff537D4F),
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
                    style: TextStyle(color: Color(0xff537D4F), fontSize: 18),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
