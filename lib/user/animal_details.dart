import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/user/cart_service.dart';
import 'package:qurbani1/user/special_request.dart';

class AnimalDetailPage extends StatelessWidget {
  final String animalId;

  const AnimalDetailPage({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Animal Details")),
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

          // ✅ SAFE qty parsing (int / string)
          final rawQty = data['qty'];
          final int qty = rawQty is int
              ? rawQty
              : int.tryParse(rawQty?.toString() ?? '0') ?? 0;

          final bool isAvailable = qty > 0;

          // ✅ SAFE image URL
          final String imageUrl =
              (data['photoUrl'] is String &&
                      data['photoUrl'].toString().startsWith('http'))
                  ? data['photoUrl']
                  : '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Image
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 220,
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
                      Text(
                        data['type'] ?? 'Animal',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        "₹ ${data['price'] ?? 0}",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        isAvailable ? "In Stock: $qty" : "Out of Stock",
                        style: TextStyle(
                          color: isAvailable ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

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
                                        content: Text("Added to cart"),
                                      ),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Add to Cart",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ✅ Special Request Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: currentUser != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SpecialRequestPage(
                                        userId: currentUser.uid,
                                        animalId: animalId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "Special Request",
                            style: TextStyle(fontSize: 16),
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

  /// ❌ Fallback when image is missing or invalid
  Widget _imageFallback() {
    return Container(
      height: 220,
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
