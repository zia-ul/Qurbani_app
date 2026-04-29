import 'package:Qurbani/screens/admin/add_animal_details.dart';
import 'package:Qurbani/screens/admin/barcode_page.dart';
import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/screens/admin/animal_orders_page.dart';
import 'package:intl/intl.dart';

class AnimalListingPage extends StatefulWidget {
  const AnimalListingPage({super.key});

  @override
  State<AnimalListingPage> createState() => _AnimalListingPageState();
}

class _AnimalListingPageState extends State<AnimalListingPage> {
  final _storage = const FlutterSecureStorage();

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> animals = [];

  bool isLoading = false;
  bool isFetchingMore = false;
  bool hasMore = true;

  int page = 1;
  final int limit = 10;

  String searchQuery = "";
  String? _loadError;

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
        _loadError = null;
      });
    } else {
      setState(() => isFetchingMore = true);
    }

    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final response = await ApiClient.get(
        ApiClient.uri(
          'animals',
          queryParameters: {'page': page, 'limit': limit},
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final decoded = ApiClient.decodeMap(
          response,
          fallbackMessage: "Unable to load animals right now.",
        );

        final List newAnimals = decoded['animals'] ?? [];

        if (!mounted) return;
        setState(() {
          animals.addAll(newAnimals.cast<Map<String, dynamic>>());
          hasMore = decoded['pagination']?['hasMore'] ?? false;
          page++;
          _loadError = null;
        });
      } else {
        final message = ApiClient.errorMessage(
          response,
          fallbackMessage: "Unable to load animals right now.",
        );
        if (!mounted) return;
        setState(() => _loadError = message);
        ToastUtils.showError(message);
      }
    } catch (e, stack) {
      AppLogger.error("Failed to fetch animals", e, stack);
      final message = _friendlyErrorMessage(
        e,
        fallback: "Unable to load animals right now.",
      );
      if (!mounted) return;
      setState(() => _loadError = message);
      ToastUtils.showError(message);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isFetchingMore = false;
        });
      }
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

      final response = await ApiClient.delete(
        ApiClient.uri("animals/$animalId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        ToastUtils.showSuccess("Animal deleted successfully");
        fetchAnimals(initial: true);
      } else {
        ToastUtils.showError(
          ApiClient.errorMessage(
            response,
            fallbackMessage: "Unable to delete the animal right now.",
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error("Failed to delete animal", e, stack);
      ToastUtils.showError(
        _friendlyErrorMessage(
          e,
          fallback: "Unable to delete the animal right now.",
        ),
      );
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
          : _loadError != null && animals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => fetchAnimals(initial: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: AppTheme.bgGradientEnd,
                      ),
                      child: const Text("Try Again"),
                    ),
                  ],
                ),
              ),
            )
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

  String formatQurbaniDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return "Not set";

    try {
      final dt = DateTime.parse(dateTime).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return dateTime;
    }
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final String animalType = animal['animal_type'] ?? '';
    final String barcode = animal['barcode'] ?? '';
    final String pricePerShare =
        (double.tryParse(animal['price_per_share']?.toString() ?? '') ?? 0)
            .toStringAsFixed(2);
    final String qurbaniDateTime = formatQurbaniDateTime(
      animal['qurbani_datetime']?.toString(),
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              animalType,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              "Barcode: $barcode",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 6),

            Text(
              "Price per Share: Rs. $pricePerShare",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),

            const SizedBox(height: 6),

            Text(
              "Qurbani Date & Time: $qurbaniDateTime",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),

            const SizedBox(height: 12),
            const Divider(),

            Row(
              children: [
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
