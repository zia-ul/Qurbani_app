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
      appBar: AppBar(title: const Text("Animal Details"), backgroundColor: Colors.green),
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
              (data['photoUrl'] is String && data['photoUrl'].toString().startsWith('http'))
                  ? data['photoUrl']
                  : '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
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
                      // Barcode
                      Text(
                        "Barcode: ${data['barcode'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        data['title'] ?? data['type'] ?? 'Animal',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(
                        data['description'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      // Weight
                      Text(
                        "Weight: ${data['weight'] ?? 'N/A'} kg",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),

                      // Price
                      Text(
                        "Price: ₹ ${data['price']?.toStringAsFixed(2) ?? '0.00'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),

                      // Shares
                      Text(
                        "Shares: $shares",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      // Tags: Animal Type & Health Status
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

                      // Add to Cart Button
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
                                      const SnackBar(content: Text("Added to cart")),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable ? Colors.green : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isAvailable ? "Add to Cart" : "Out of Stock",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      // const SizedBox(height: 10),

                      // // Special Request Button
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: ElevatedButton(
                      //     onPressed: currentUser != null
                      //         ? () {
                      //             Navigator.push(
                      //               context,
                      //               MaterialPageRoute(
                      //                 builder: (_) => SpecialRequestPage(
                      //                   userId: currentUser.uid,
                      //                   animalId: animalId,
                      //                 ),
                      //               ),
                      //             );
                      //           }
                      //         : null,
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Colors.orange,
                      //       padding: const EdgeInsets.symmetric(vertical: 14),
                      //     ),
                      //     child: const Text(
                      //       "Special Request",
                      //       style: TextStyle(fontSize: 16),
                      //     ),
                      //   ),
                      // ),
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

  /// Tag widget with light green background and green border
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

  /// Fallback for invalid/missing image
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
