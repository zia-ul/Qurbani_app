import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/user/cart_service.dart';

class AnimalDetailPage extends StatelessWidget {
  final String animalId;

  const AnimalDetailPage({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Animal Details"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('animals')
            .doc(animalId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Animal not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final rawQty = data['shares'];
          final int shares = rawQty is int
              ? rawQty
              : int.tryParse(rawQty?.toString() ?? '0') ?? 0;

          final bool isAvailable = data['isAvailable'] ?? true;

          final String imageUrl =
              (data['photoUrl'] is String &&
                      data['photoUrl'].toString().startsWith('http'))
                  ? data['photoUrl']
                  : '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// IMAGE
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// BARCODE
                      Text(
                        "Barcode: ${data['barcode'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      /// TITLE
                      Text(
                        data['title'] ?? data['type'] ?? 'Animal',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      /// ⭐ AVERAGE RATING
                      _averageRatingWidget(animalId),

                      const SizedBox(height: 12),

                      /// DESCRIPTION
                      Text(
                        data['description'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      /// WEIGHT
                      Text(
                        "Weight: ${data['weight'] ?? 'N/A'} kg",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),

                      /// PRICE
                      Text(
                        "Price: ₹ ${data['price']?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),

                      /// SHARES
                      Text(
                        "Shares: $shares",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      /// TAGS
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (data['type'] != null)
                            _tagWidget(data['type']),
                          if (data['healthStatus'] != null)
                            _tagWidget(data['healthStatus']),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// ADD TO CART
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isAvailable
                              ? () async {
                                  try {
                                    await CartService.addAnimalToCart(
                                      animalId: animalId,
                                      animalData: data,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Added to cart")),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isAvailable ? Colors.green : Colors.grey,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isAvailable ? "Add to Cart" : "Out of Stock",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ⭐ Average Rating Widget
  Widget _averageRatingWidget(String animalId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('animal_ratings')
          .where('animalId', isEqualTo: animalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text(
            "No ratings yet",
            style: TextStyle(color: Colors.grey),
          );
        }

        double total = 0;
        for (var d in docs) {
          total += (d['rating'] ?? 0).toDouble();
        }

        final avg = total / docs.length;

        return Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "(${docs.length} reviews)",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  /// TAG WIDGET
  Widget _tagWidget(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// IMAGE FALLBACK
  Widget _imageFallback() {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.image_not_supported,
        size: 80,
        color: Colors.grey,
      ),
    );
  }
}
