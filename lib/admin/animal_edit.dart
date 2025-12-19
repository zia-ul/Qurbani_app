import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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
  final TextEditingController _sharesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _healthController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _photoUrl; // Stores current photo URL
  File? _image; // Stores newly picked image
  bool _loading = true;

  final ImagePicker _picker = ImagePicker();

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
      _priceController.text = (data['price'] ?? '').toString();
      _sharesController.text = (data['shares'] ?? '').toString();
      _weightController.text = data['weight'] ?? '';
      _breedController.text = data['breed'] ?? '';
      _healthController.text = data['healthStatus'] ?? '';
      _descController.text = data['description'] ?? '';
      _photoUrl = data['photoUrl'];
    }

    setState(() => _loading = false);
  }

  Future<void> pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _photoUrl = null; // clear previous URL when new image selected
      });
    }
  }

  Future<void> _updateAnimal() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('animals')
          .doc(widget.animalId)
          .update({
        'title': _titleController.text.trim(),
        'price': int.tryParse(_priceController.text.trim()) ?? 0,
        'shares': int.tryParse(_sharesController.text.trim()) ?? 0,
        'weight': _weightController.text.trim(),
        'breed': _breedController.text.trim(),
        'healthStatus': _healthController.text.trim(),
        'description': _descController.text.trim(),
        'photoUrl': _photoUrl ?? '', // For real app, upload _image to storage first
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Animal updated successfully")),
      );
      Navigator.pop(context);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator:
            validator ?? (v) => v == null || v.isEmpty ? "$label is required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _image == null ? pickImage : null,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                image: _image == null && _photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _image == null && _photoUrl == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 40),
                        SizedBox(height: 8),
                        Text("Tap to select image"),
                      ],
                    )
                  : (_image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _image!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null),
            ),
            if (_image != null || _photoUrl != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _image = null;
                    _photoUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Animal"),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field(_typeController, "Animal Type", enabled: false),
                _field(_titleController, "Title"),
                _field(_priceController, "Price", keyboardType: TextInputType.number),
                _field(_sharesController, "Shares", keyboardType: TextInputType.number),
                _field(_weightController, "Weight"),
                _field(_breedController, "Breed"),
                _field(_healthController, "Health Status"),
                _field(_descController, "Description"),
                _photoPicker(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updateAnimal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Update Animal",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
