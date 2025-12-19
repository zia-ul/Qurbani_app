import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/animal_details.dart';
import 'package:qurbani1/user/cart_badge.dart';
import 'package:qurbani1/user/cart_service.dart';

/// =======================
/// MODEL
/// =======================
class Animal {
  final String id;
  final String adminId;
  final String adminName;
  final String type;
  final String? title;
  final double price;
  final int shares;
  final String photoUrl;
  final bool isAvailable;

  Animal({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.type,
    this.title,
    required this.price,
    required this.shares,
    required this.photoUrl,
    required this.isAvailable,
  });

  static Animal fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Animal(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Unknown',
      type: data['type'] ?? '',
      title: data['title'],
      price: data['price'] is num
          ? (data['price'] as num).toDouble()
          : double.tryParse(data['price']?.toString() ?? '0') ?? 0,
      shares: data['shares'] is int
          ? data['shares']
          : int.tryParse(data['shares']?.toString() ?? '0') ?? 0,
      photoUrl: data['photoUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
    );
  }
}

/// =======================
/// ANIMAL GRID PAGE
/// =======================
class AnimalGridPage extends StatelessWidget {
  const AnimalGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qurbani Marketplace"),
        backgroundColor: Colors.green,
        actions: [CartBadge(userId: userId)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('animals')
            .where('isAvailable', isEqualTo: true) // Show only available animals
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No animals available"));
          }

          final animals = snapshot.data!.docs
              .map((e) => Animal.fromFirestore(e))
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              final imageUrl = animal.photoUrl.startsWith('http')
                  ? animal.photoUrl
                  : '';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.green, width: 0.8),
                ),
                child: Column(
                  children: [
                    /// IMAGE
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imageFallback(),
                              )
                            : _imageFallback(),
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// DETAILS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animal.title ?? animal.type,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "₹ ${animal.price.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "Shares: ${animal.shares}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// ACTION BUTTONS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye),
                            tooltip: "View",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnimalDetailPage(animalId: animal.id),
                                ),
                              );
                            },
                          ),

                          ElevatedButton(
                            onPressed: animal.isAvailable
                                ? () async {
                                    await CartService.addAnimalToCart(
                                      animalId: animal.id,
                                      animalData: {
                                        'type': animal.type,
                                        'title': animal.title,
                                        'price': animal.price,
                                        'shares': animal.shares,
                                        'photoUrl': animal.photoUrl,
                                        'adminId': animal.adminId,
                                        'adminName': animal.adminName,
                                      },
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Added to cart"),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: animal.isAvailable
                                  ? Colors.green
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            child: Text(
                              animal.isAvailable ? "Add" : "Out of stock",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// IMAGE FALLBACK
  Widget _imageFallback() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
      ),
    );
  }
}
