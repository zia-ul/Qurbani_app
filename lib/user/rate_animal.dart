import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RateAnimalPage extends StatefulWidget {
  final String animalId;
  final String orderId;
  final String userId;

  const RateAnimalPage({
    super.key,
    required this.animalId,
    required this.orderId,
    required this.userId,
  });

  @override
  State<RateAnimalPage> createState() => _RateAnimalPageState();
}

class _RateAnimalPageState extends State<RateAnimalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double rating = 0;
  bool submitted = false;

  Future<void> submitRating() async {
    if (rating == 0) return;

    final docId =
        "${widget.animalId}_${widget.orderId}_${widget.userId}";

    await _firestore.collection('animal_ratings').doc(docId).set({
      'animalId': widget.animalId,
      'orderId': widget.orderId,
      'userId': widget.userId,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => submitted = true);
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: submitted ? null : () => setState(() => rating = i + 1),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Animal"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "How was this animal?",
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                _stars(),
                const SizedBox(height: 20),
                if (!submitted)
                  ElevatedButton(
                    onPressed: submitRating,
                    child: const Text("Submit Rating"),
                  )
                else
                  const Text(
                    "⭐ Rating submitted",
                    style: TextStyle(color: Colors.green),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
