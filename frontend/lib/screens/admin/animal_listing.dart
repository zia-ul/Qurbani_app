import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:Qurbani/screens/admin/animal_edit.dart';
import 'package:Qurbani/screens/admin/animal_orders_page.dart'; // New page
import 'package:Qurbani/services/currency_notifier.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnimalListingPage extends StatefulWidget {
  const AnimalListingPage({super.key});

  @override
  State<AnimalListingPage> createState() => _AnimalListingPageState();
}

class _AnimalListingPageState extends State<AnimalListingPage> {
  final _storage = const FlutterSecureStorage();
  static final String? _baseUrl =  dotenv.env['BASE_URL'];
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
        ToastUtils.showError("Failed to fetch animals: ${response.body}");
      }
    } catch (e) {
      print(e);
      ToastUtils.showError("Something went wrong");
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
        ToastUtils.showSuccess("Animal deleted successfully");
        fetchAnimals(); // Refresh list
      } else {
        ToastUtils.showError("Failed to delete animal: ${response.body}");
      }
    } catch (e) {
      print(e);
      ToastUtils.showError("Something went wrong");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // For gradient
      appBar: AppBar(
        title: const Text("Animal Management"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : animals.isEmpty
          ? const Center(child: Text("No animals found."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: animals.length,
              itemBuilder: (context, index) {
                final animal = animals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAnimalCard(animal, AppTheme.primaryGreen),
                );
              },
            ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal, Color primaryGreen) {
    return GestureDetector(
      onTap: () {
        // Make card clickable to view orders
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimalOrdersPage(
              animalId: animal['id'],
              animalName:
                  "${animal['breed'] ?? ''} (${animal['animal_type'] ?? ''})",
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder or actual image
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: animal['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          animal['image_url'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                "${animal['breed'] ?? ''} (${animal['animal_type'] ?? ''})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "ID: ${animal['id']}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Consumer<CurrencyNotifier>(
                builder: (context, currency, child) {
                  // Convert to double safely
                  final rawPrice = animal['price'] ?? 0;
                  final price = currency.convert(
                    (rawPrice is String)
                        ? double.tryParse(rawPrice) ?? 0
                        : rawPrice.toDouble(),
                  );

                  return Text(
                    "Price: ${currency.currency} ${price.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),

              // const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnimalOrdersPage(
                              animalId: animal['id'],
                              animalName:
                                  "${animal['breed'] ?? ''} (${animal['animal_type'] ?? ''})",
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text("View"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // IconButton(
                  //   onPressed: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) =>
                  //             AnimalEditPage(animalId: animal['id'].toString()),
                  //       ),
                  //     );
                  //   },
                  //   icon: const Icon(Icons.edit, size: 20),
                  //   color: AppTheme.primaryGreen,
                  // ),
                  IconButton(
                    onPressed: () => deleteAnimal(animal['id']),
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
