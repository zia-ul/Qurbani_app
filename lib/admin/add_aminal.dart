import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:qurbani1/admin/barcode_page.dart';
import 'package:qurbani1/user/location_picker.dart';

class AddAnimalPage extends StatefulWidget {
  const AddAnimalPage({super.key});

  @override
  State<AddAnimalPage> createState() => _AddAnimalPageState();
}

class _AddAnimalPageState extends State<AddAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final breedController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final barcodeController = TextEditingController();
  final priceController = TextEditingController();
  final locationController = TextEditingController();

  String? animalType;
  String? selectedHealth;

  /// 📍 Location data
  String? locationAddress;
  double? locationLat;
  double? locationLng;

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;

  /// 🔢 Barcode
  String generateBarcode() => "AN-${DateTime.now().millisecondsSinceEpoch}";

  /// 📸 Pick image
  Future<void> pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void removeImage() => setState(() => _image = null);

  /// ☁️ Upload to Cloudinary
  Future<String> uploadImageToCloudinary() async {
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
      throw Exception("Image upload failed");
    }
  }

  /// 🐄 Add animal
  Future<void> addAnimal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select image")));
      return;
    }

    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    setState(() => isLoading = true);

    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(admin.uid)
          .get();

      final adminName = adminDoc.data()?['name'] ?? 'Admin';

      final docRef = FirebaseFirestore.instance.collection('animals').doc();
      final animalId = docRef.id;
      final imageUrl = await uploadImageToCloudinary();

      int shares =
          (animalType == "camel" || animalType == "buffalo") ? 7 : 1;

      await docRef.set({
        'animalId': animalId,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'type': animalType,
        'breed': breedController.text.trim(),
        'age': ageController.text.trim(),
        'weight': weightController.text.trim(),
        'healthStatus': selectedHealth,
        'shares': shares,
        'barcode': barcodeController.text,
        'price': double.tryParse(priceController.text) ?? 0,
        'photoUrl': imageUrl,

        /// 📍 Location
        'location': {
          'address': locationAddress,
          'latitude': locationLat,
          'longitude': locationLng,
        },

        'adminId': admin.uid,
        'adminName': adminName,
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    breedController.dispose();
    ageController.dispose();
    weightController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Add Animal"), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// 📸 Image Picker
              GestureDetector(
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
                      ),
                      child: _image == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40),
                                SizedBox(height: 8),
                                Text("Tap to select image"),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 160,
                              ),
                            ),
                    ),
                    if (_image != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: removeImage,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: titleController,
                decoration: inputStyle("Animal Title", Icons.text_fields),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: inputStyle("Description", Icons.description),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: breedController,
                decoration: inputStyle("Breed", Icons.info),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

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
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: barcodeController,
                      readOnly: true,
                      decoration: inputStyle("Barcode", Icons.qr_code),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        barcodeController.text = generateBarcode(),
                    child: const Text("Generate"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: inputStyle("Price", Icons.currency_rupee),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: ageController,
                decoration: inputStyle("Age", Icons.calendar_today),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: weightController,
                decoration: inputStyle("Weight", Icons.monitor_weight),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration:
                    inputStyle("Health Status", Icons.health_and_safety),
                items: const [
                  DropdownMenuItem(value: "Healthy", child: Text("Healthy")),
                  DropdownMenuItem(value: "Average", child: Text("Average")),
                  DropdownMenuItem(value: "Weak", child: Text("Weak")),
                ],
                onChanged: (v) => selectedHealth = v,
                validator: (v) => v == null ? "Select health" : null,
              ),
              const SizedBox(height: 16),

              /// 📍 Location Picker
              TextFormField(
                controller: locationController,
                decoration: inputStyle("Visit Location", Icons.location_on)
                    .copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map, color: Colors.green),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationPickerPage(),
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          locationController.text = result['address'];
                          locationLat = result['latitude'];
                          locationLng = result['longitude'];
                        });
                      }
                    },
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Location required" : null,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text("Current"),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationPickerPage(),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            locationAddress = result['address'];
                            locationLat = result['latitude'];
                            locationLng = result['longitude'];
                            locationController.text = locationAddress!;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text("Map"),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationPickerPage(),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            locationAddress = result['address'];
                            locationLat = result['latitude'];
                            locationLng = result['longitude'];
                            locationController.text = locationAddress!;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
