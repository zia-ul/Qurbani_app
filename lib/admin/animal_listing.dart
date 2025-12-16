import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/admin/animal_edit.dart';

class AnimalListingPage extends StatelessWidget {
  const AnimalListingPage({super.key});

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
        title: const Text("Your Animal Stock"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('animals')
            .where('adminId', isEqualTo: user.uid) // only admin's animals
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
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: animal['photoUrl'] != null
                    ? Image.network(
                        animal['photoUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.pets),
                title: Text(animal['type'] ?? 'Unknown'),
                subtitle: Text("Price: ₹${animal['price'] ?? '0'}"),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnimalEditPage(
                        animalId: animals[index].id,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
