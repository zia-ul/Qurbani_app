import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/admin/animal_edit.dart';

class AnimalListingPage extends StatelessWidget {
  const AnimalListingPage({super.key});

  Future<void> _deleteAnimal(BuildContext context, String animalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Animal"),
        content: const Text("Are you sure you want to delete this animal?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('animals')
          .doc(animalId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Animal deleted successfully")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No admin logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Animal Inventory"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('animals')
            .where('adminId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final animals = snapshot.data!.docs;

          if (animals.isEmpty) {
            return const Center(child: Text("No animals listed yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final doc = animals[index];
              final animal = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.green),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                              image: animal['photoUrl'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(animal['photoUrl']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Colors.grey.shade200,
                            ),
                            width: 70,
                            height: 70,
                            child: animal['photoUrl'] == null
                                ? const Icon(Icons.pets, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  animal['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Type: ${animal['type'] ?? 'N/A'}",
                                ),
                                Text(
                                  "Price: ₹${animal['price'] ?? 0}",
                                ),
                                Text(
                                  "Shares: ${animal['shares'] ?? 0}",
                                ),
                                Text(
                                  "Available: ${animal['isAvailable'] == true ? 'Yes' : 'No'}",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit, color: Colors.green),
                            label: const Text(
                              "Edit",
                              style: TextStyle(color: Colors.green),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnimalEditPage(
                                    animalId: doc.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () => _deleteAnimal(context, doc.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
