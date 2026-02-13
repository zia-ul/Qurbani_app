import 'dart:convert';

import 'package:Qurbani/screens/admin/add_animal_details.dart';
import 'package:Qurbani/screens/admin/barcode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:Qurbani/services/currency_notifier.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/screens/admin/animal_orders_page.dart';

class AnimalListingPage extends StatefulWidget {
  const AnimalListingPage({super.key});

  @override
  State<AnimalListingPage> createState() => _AnimalListingPageState();
}

class _AnimalListingPageState extends State<AnimalListingPage> {
  final _storage = const FlutterSecureStorage();
  static final String _baseUrl = dotenv.env['BASE_URL']!;

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> animals = [];

  bool isLoading = false;
  bool isFetchingMore = false;
  bool hasMore = true;

  int page = 1;
  final int limit = 10;

  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchAnimals(initial: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isFetchingMore &&
          hasMore) {
        fetchAnimals();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🔹 Fetch animals with pagination
  Future<void> fetchAnimals({bool initial = false}) async {
    if (initial) {
      setState(() {
        page = 1;
        animals.clear();
        hasMore = true;
        isLoading = true;
      });
    } else {
      setState(() => isFetchingMore = true);
    }

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final uri = Uri.parse("$_baseUrl/animals?page=$page&limit=$limit");

      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final List newAnimals = decoded['animals'] ?? [];

        setState(() {
          animals.addAll(newAnimals.cast<Map<String, dynamic>>());
          hasMore = decoded['pagination']?['hasMore'] ?? false;
          page++;
        });
      } else {
        ToastUtils.showError("Failed to load animals");
      }
    } catch (e) {
      ToastUtils.showError("Something went wrong");
    } finally {
      setState(() {
        isLoading = false;
        isFetchingMore = false;
      });
    }
  }

  // 🔹 Delete animal
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
            child: const Text(
              "Delete",
              style: TextStyle(color: AppTheme.warningRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await http.delete(
        Uri.parse("$_baseUrl/animals/$animalId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Animal deleted successfully");
        fetchAnimals(initial: true);
      } else {
        ToastUtils.showError("Failed to delete animal");
      }
    } catch (e) {
      ToastUtils.showError("Something went wrong");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Animal Management"),
        backgroundColor: AppTheme.primaryGreen,
      ),

      // ➕ Add Animal Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAnimalPage()),
          );

          if (added == true) {
            fetchAnimals(initial: true);
          }
        },
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : animals.isEmpty
          ? const Center(child: Text("No animals found."))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: animals.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == animals.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final animal = animals[index];
                return _buildAnimalCard(animal);
              },
            ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final String animalType = animal['animal_type'] ?? '';
    final String barcode = animal['barcode'] ?? '';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Animal Type
            Text(
              animalType,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            /// 🔹 Barcode
            Text(
              "Barcode: $barcode",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 12),
            const Divider(),

            /// 🔹 Buttons Row
            Row(
              children: [
                /// View Orders
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text("View Orders"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnimalOrdersPage(
                            animalId: animal['id'],
                            animalName: animalType,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 8),

                /// Print Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text("Print"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BarcodePage(barcodeValue: barcode),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 8),

                /// Delete
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: AppTheme.warningRed,
                  onPressed: () => deleteAnimal(animal['id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
