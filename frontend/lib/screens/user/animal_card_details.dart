import 'package:flutter/material.dart';

class AnimalDetailsCard extends StatelessWidget {
  final String type;
  final String breed;
  final String description;
  final int age;

  const AnimalDetailsCard({
    super.key,
    required this.type,
    required this.breed,
    required this.description,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 2.5, 14, 2.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff537D4F)),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: const [
                Icon(Icons.circle, color: Color(0xff537D4F)),
                SizedBox(width: 8),
                Text(
                  "Animal Details",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff537D4F),
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1, height: 20),
            
            // Type
            Row(
              children: [
                const Text(
                  "Type: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(type),
              ],
            ),
            const SizedBox(height: 8),

            // Breed
            Row(
              children: [
                const Text(
                  "Breed: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(breed),
              ],
            ),
            const SizedBox(height: 8),

            // Age
            Row(
              children: [
                const Text(
                  "Age: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("$age months"),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Description: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(child: Text(description)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
