import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani/screens/admin/animal_edit.dart';

class AnimalListingPage extends StatefulWidget {
  const AnimalListingPage({super.key});

  @override
  State<AnimalListingPage> createState() => _AnimalListingPageState();
}

class _AnimalListingPageState extends State<AnimalListingPage> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = "http://192.168.1.6:3000/api";
  List animals = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchAnimals();
  }

  // Fetch animals added by the logged-in admin
  Future<void> fetchAnimals() async {
    setState(() => isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final url = Uri.parse("$_baseUrl/animals");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => animals = data['animals'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch animals: ${response.body}")),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Delete animal
  Future<void> deleteAnimal(String animalId) async {
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
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final url = Uri.parse("$_baseUrl/animals/$animalId");
      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Animal deleted successfully")),
        );
        fetchAnimals(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete animal: ${response.body}")),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Animal Management")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : animals.isEmpty
          ? const Center(child: Text("No animals found."))
          : ListView.builder(
              itemCount: animals.length,
              itemBuilder: (context, index) {
                final animal = animals[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${animal['breed'] ?? ''} (${animal['animal_type'] ?? ''})",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text("ID: ${animal['id']}"),
                        Text("Price: ${animal['price'] ?? 0}"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnimalEditPage(
                                      animalId: animal['id'].toString(),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text("Edit"),
                            ),

                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => deleteAnimal(animal['id']),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text("Delete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
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
