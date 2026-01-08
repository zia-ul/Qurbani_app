import 'package:flutter/material.dart';

/// 🔍 Filter types supported
enum AnimalSortOption { newest, priceLowToHigh, priceHighToLow }

/// =======================
/// SEARCH + FILTER BAR
/// =======================
class AnimalFilterBar extends StatelessWidget {
  final String searchText;
  final String? selectedBreed;
  final List<String> availableBreeds;
  final AnimalSortOption sortOption;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBreedChanged;
  final ValueChanged<AnimalSortOption> onSortChanged;

  const AnimalFilterBar({
    super.key,
    required this.searchText,
    required this.selectedBreed,
    required this.availableBreeds,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onBreedChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🔍 SEARCH BAR
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by breed...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),

        /// 🎛️ FILTER ROW
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              /// 🐄 BREED FILTER
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBreed,
                  hint: const Text("Breed"),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("All Breeds"),
                    ),
                    ...availableBreeds.map(
                      (breed) =>
                          DropdownMenuItem(value: breed, child: Text(breed)),
                    ),
                  ],
                  onChanged: onBreedChanged,
                ),
              ),

              const SizedBox(width: 8),

              /// 🔃 SORT FILTER
              Expanded(
                child: DropdownButtonFormField<AnimalSortOption>(
                  initialValue: sortOption,
                  items: const [
                    DropdownMenuItem(
                      value: AnimalSortOption.newest,
                      child: Text("Newest"),
                    ),
                    DropdownMenuItem(
                      value: AnimalSortOption.priceLowToHigh,
                      child: Text("Price ↑"),
                    ),
                    DropdownMenuItem(
                      value: AnimalSortOption.priceHighToLow,
                      child: Text("Price ↓"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
