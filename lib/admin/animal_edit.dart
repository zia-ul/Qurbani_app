import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnimalEditPage extends StatefulWidget {
  final String animalId;

  const AnimalEditPage({super.key, required this.animalId});

  @override
  State<AnimalEditPage> createState() => _AnimalEditPageState();
}

class _AnimalEditPageState extends State<AnimalEditPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnimalDetails();
  }

  Future<void> _loadAnimalDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('animals')
        .doc(widget.animalId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _typeController.text = data['type'] ?? '';
      _titleController.text = data['title'] ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _qtyController.text = data['qty']?.toString() ?? '';
      _photoUrlController.text = data['photoUrl'] ?? '';
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _updateAnimal() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('animals')
          .doc(widget.animalId)
          .update({
        'type': _typeController.text.trim(),
        'title': _titleController.text.trim(),
        'price': int.tryParse(_priceController.text.trim()) ?? 0,
        'qty': int.tryParse(_qtyController.text.trim()) ?? 0,
        'photoUrl': _photoUrlController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Animal updated successfully")),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Animal"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: "Animal Type"),
                validator: (val) =>
                    val == null || val.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _qtyController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _photoUrlController,
                decoration: const InputDecoration(labelText: "Photo URL"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateAnimal,
                child: const Text("Update Animal"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
