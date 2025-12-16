import 'package:flutter/material.dart';
import 'generate_stickers.dart';

class ActiveShareholdersPage extends StatelessWidget {
  const ActiveShareholdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Properly typed list of shareholders
    final List<Map<String, dynamic>> shareholders = [
      {"name": "Ali", "phone": "123456789", "shares": 3},
      {"name": "Sara", "phone": "987654321", "shares": 2},
      {"name": "Hassan", "phone": "456123789", "shares": 5},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Active Shareholders")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: "Search Shareholder",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // List of shareholders
            Expanded(
              child: ListView.builder(
                itemCount: shareholders.length,
                itemBuilder: (context, index) {
                  final s = shareholders[index];
                  return Card(
                    child: ListTile(
                      title: Text(s["name"].toString()),
                      subtitle: Text(
                        "Shares: ${s["shares"].toString()} | Phone: ${s["phone"].toString()}",
                      ),
                      trailing: ElevatedButton(
                        child: const Text("View"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GenerateStickersPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
