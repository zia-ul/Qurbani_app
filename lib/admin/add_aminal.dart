import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani1/admin/barcode_page.dart';

class AddAnimalPage extends StatefulWidget {
  const AddAnimalPage({super.key});

  @override
  State<AddAnimalPage> createState() => _AddAnimalPageState();
}

class _AddAnimalPageState extends State<AddAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final qtyController = TextEditingController(text: "1");
  final weightController = TextEditingController();
  final ageController = TextEditingController();
  final priceController = TextEditingController();
  final barcodeController = TextEditingController();

  String? animalType;
  String? selectedGender;
  String? selectedHealth;

  File? _image;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;

  /// 🔑 Generate unique barcode
  String generateBarcode() {
    return "AN-${DateTime.now().millisecondsSinceEpoch}";
  }

  /// 📸 Pick image
  Future<void> pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  /// ☁️ Upload image to Cloudinary
  Future<String> uploadImageToCloudinary() async {
    if (_image == null) throw Exception("No image selected");

    // Replace these with your Cloudinary credentials
    const cloudName = 'dfezveorl';
    const uploadPreset = 'qurbani';

    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

    final response = await request.send();
    final resStr = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(resStr);
      return jsonResp['secure_url'];
    } else {
      throw Exception('Cloudinary upload failed: $resStr');
    }
  }

  /// ✅ Add animal
  Future<void> addAnimal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    setState(() => isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('animals').doc();
      final animalId = docRef.id;

      final imageUrl = await uploadImageToCloudinary();

      await docRef.set({
        'animalId': animalId,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'type': animalType,
        'price': double.parse(priceController.text),
        'qty': int.parse(qtyController.text),
        'weight': weightController.text.trim(),
        'age': ageController.text.trim(),
        'gender': selectedGender,
        'healthStatus': selectedHealth,
        'barcode': barcodeController.text,
        'photoUrl': imageUrl,
        'adminId': admin.uid,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Animal added successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodePage(animalId: animalId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Animal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// IMAGE PICKER
              GestureDetector(
                onTap: pickImage,
                child: _image == null
                    ? Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40),
                            SizedBox(height: 8),
                            Text("Tap to select image"),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: titleController,
                decoration: inputStyle("Animal Title", Icons.text_fields),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: inputStyle("Description", Icons.description),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: inputStyle("Animal Type", Icons.pets),
                items: const [
                  DropdownMenuItem(value: "goat", child: Text("Goat")),
                  DropdownMenuItem(value: "sheep", child: Text("Sheep")),
                  DropdownMenuItem(value: "camel", child: Text("Camel")),
                  DropdownMenuItem(value: "buffalo", child: Text("Buffalo")),
                ],
                onChanged: (v) => animalType = v,
                validator: (v) => v == null ? "Select type" : null,
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: barcodeController,
                      readOnly: true,
                      decoration: inputStyle("Barcode", Icons.qr_code),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      barcodeController.text = generateBarcode();
                    },
                    child: const Text("Generate"),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: inputStyle("Price", Icons.currency_rupee),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: inputStyle("Quantity", Icons.confirmation_number),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: inputStyle("Gender", Icons.male),
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                ],
                onChanged: (v) => selectedGender = v,
                validator: (v) => v == null ? "Select gender" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: inputStyle("Health Status", Icons.health_and_safety),
                items: const [
                  DropdownMenuItem(value: "Healthy", child: Text("Healthy")),
                  DropdownMenuItem(value: "Average", child: Text("Average")),
                  DropdownMenuItem(value: "Weak", child: Text("Weak")),
                ],
                onChanged: (v) => selectedHealth = v,
                validator: (v) => v == null ? "Select health" : null,
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : addAnimal,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Animal"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
