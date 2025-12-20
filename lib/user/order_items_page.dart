import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/animal_details.dart';
import 'package:qurbani1/user/rate_animal.dart';

class OrderItemsPage extends StatelessWidget {
  final String orderId;
  final String userId;
  final List<Map<String, dynamic>> cartItems;

  const OrderItemsPage({
    super.key,
    required this.orderId,
    required this.userId,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ordered Animals"),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        itemCount: cartItems.length,
        itemBuilder: (_, i) {
          final item = cartItems[i];
          final animalId = item['animalId'];

          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'Animal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Shares: ${item['shares']}"),

                  const SizedBox(height: 12),

                  /// 🔹 CHECK IF ALREADY RATED
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('animal_ratings')
                        .where('animalId', isEqualTo: animalId)
                        .where('orderId', isEqualTo: orderId)
                        .where('userId', isEqualTo: userId)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }

                      final hasRated =
                          snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                      /// ⭐ ALREADY RATED UI
                      if (hasRated) {
                        final ratingDoc = snapshot.data!.docs.first;
                        final rating =
                            (ratingDoc['rating'] ?? 0).toDouble();

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              child: const Text("View Animal"),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AnimalDetailPage(
                                      animalId: animalId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }

                      /// 📝 NOT RATED YET
                      return Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          child: const Text("Rate"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RateAnimalPage(
                                  animalId: animalId,
                                  orderId: orderId,
                                  userId: userId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
