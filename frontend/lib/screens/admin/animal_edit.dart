import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani/theme/theme.dart';
import 'dart:convert';
import 'package:qurbani/widgets/primary_btn.dart';
import 'package:qurbani/widgets/common_card.dart';
import 'package:qurbani/widgets/common_label.dart';
import 'package:qurbani/widgets/common_input_decoration.dart';
import 'package:qurbani/widgets/custom_toast.dart';
import 'package:qurbani/widgets/success_error_popup.dart';

class AnimalEditPage extends StatefulWidget {
  final String animalId;

  const AnimalEditPage({super.key, required this.animalId});

  @override
  State<AnimalEditPage> createState() => _AnimalEditPageState();
}

class _AnimalEditPageState extends State<AnimalEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  final String _baseUrl = "http://192.168.1.6:3000/api";

  final descriptionController = TextEditingController();
  final breedController = TextEditingController();
  final priceController = TextEditingController();
  final ageController = TextEditingController();
  final sharesController = TextEditingController();
  final animalTypeController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final deliveryFeeController = TextEditingController();

  bool isLoading = true;
  bool isUpdating = false;
  List<String> existingPhotoUrls = [];
  List<XFile> newImages = [];
  final ImagePicker _picker = ImagePicker();
  List<String> selectedPaymentMethods = [];
  String? selectedAnimalType;

  final Color lightBg = const Color(0xFFF9FBF9);

  @override
  void initState() {
    super.initState();
    _loadAnimalDetails();
  }

  Future<void> _loadAnimalDetails() async {
    try {
      final token = await _storage.read(key: "token");
      if (token == null) return;

      final res = await http.get(
        Uri.parse("$_baseUrl/animals/${widget.animalId}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (res.statusCode != 200) {
        setState(() => isLoading = false);
        return;
      }

      final data = jsonDecode(res.body);

      selectedAnimalType = data['animal_type'];
      animalTypeController.text = data['animal_type'] ?? '';
      breedController.text = data['breed'] ?? '';
      descriptionController.text = data['description'] ?? '';
      priceController.text = data['price'].toString();
      ageController.text = data['age'] ?? '';
      heightController.text = data['height']?.toString() ?? '';
      weightController.text = data['weight']?.toString() ?? '';
      sharesController.text = data['shares']?.toString() ?? '';
      deliveryFeeController.text = data['delivery_fee']?.toString() ?? "0";

      existingPhotoUrls = List<String>.from(
        jsonDecode(data['photo_urls'] ?? "[]"),
      );
      selectedPaymentMethods = List<String>.from(
        jsonDecode(data['payment_methods'] ?? "[]"),
      );

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImages() async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage(
      imageQuality: 80,
    );
    if (selectedImages != null && selectedImages.isNotEmpty) {
      setState(() => newImages.addAll(selectedImages));
    }
  }

  Future<List<String>> _uploadNewImages() async {
    const cloudName = 'dfezveorl';
    const uploadPreset = 'qurbani';
    List<String> uploadedUrls = [];

    for (final image in newImages) {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final decoded = jsonDecode(await response.stream.bytesToString());
        uploadedUrls.add(decoded['secure_url']);
      }
    }
    return uploadedUrls;
  }

  Future<void> updateAnimal() async {
    if (!_formKey.currentState!.validate()) return;
    if (existingPhotoUrls.isEmpty && newImages.isEmpty) return;

    setState(() => isUpdating = true);

    try {
      final token = await _storage.read(key: "token");

      final newUrls = await _uploadNewImages();
      final allImages = [...existingPhotoUrls, ...newUrls];

      final res = await http.put(
        Uri.parse("$_baseUrl/animals/${widget.animalId}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "animalType": selectedAnimalType ?? animalTypeController.text,
          "breed": breedController.text,
          "description": descriptionController.text,
          "price": double.parse(priceController.text),
          "age": ageController.text,
          "height": heightController.text,
          "weight": weightController.text,
          "shares": int.parse(sharesController.text),
          "photoUrls": allImages,
          "paymentMethods": selectedPaymentMethods,
          "deliveryFee": double.parse(deliveryFeeController.text),
        }),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;

        ToastUtils.showSuccess('Animal updated successfully');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Animal updated successfully")),
        // );
        Navigator.pop(context);
      } else {
        throw res.body;
      }
    } catch (e) {
      ToastUtils.showError("Error: ${e.toString()}");
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: Text(
          "Edit Animal Details",
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.primaryGreen),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCardContainer([
                _buildLabel("Animal Type", isReq: true),
                DropdownButtonFormField<String>(
                  value:
                      [
                        "Goat",
                        "Buffalo",
                        "Sheep",
                        "Camel",
                      ].contains(selectedAnimalType)
                      ? selectedAnimalType
                      : null,
                  decoration: _inputDecoration("Select Type"),
                  items: ["Goat", "Buffalo", "Sheep", "Camel"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedAnimalType = val),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: animalTypeController,
                  decoration: _inputDecoration("Or Specify Type"),
                ),
                const SizedBox(height: 15),
                _buildLabel("Animal Breed", isReq: true),
                TextFormField(
                  controller: breedController,
                  decoration: _inputDecoration("e.g. Sahiwal"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                _buildLabel("Description (Optional)", isReq: false),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration("Appearance details..."),
                ),
              ]),
              const SizedBox(height: 20),
              _buildCardContainer([
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Height", isReq: true),
                          TextFormField(
                            controller: heightController,
                            decoration: _inputDecoration("cm / ft"),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // _buildLabel(
                          //   "Price (${UserCurrency.currency})",
                          //   isReq: true,
                          // ),
                          TextFormField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("0.00"),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Weight (Optional)", isReq: false),
                          TextFormField(
                            controller: weightController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("kg"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Age (Optional)", isReq: false),
                          TextFormField(
                            controller: ageController,
                            decoration: _inputDecoration("e.g. 2 yrs"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              _buildCardContainer([
                _buildLabel("Shares Available", isReq: true),
                TextFormField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration("Total Shares"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
              ]),
              const SizedBox(height: 20),
              _buildCardContainer([
                _buildLabel("Gallery (Existing & New)", isReq: true),
                const SizedBox(height: 10),
                _buildCombinedImageGallery(),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: pickImages,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text("Add More Photos"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildCardContainer([
                _buildLabel("Payment Method", isReq: true),
                Row(
                  children: [
                    _buildCheckbox("COD", 'cod'),
                    _buildCheckbox("Online", 'online'),
                  ],
                ),
              ]),
              const SizedBox(height: 30),
              PrimaryButton(
                text: "Update Animal",
                isLoading: isUpdating,
                onPressed: updateAnimal,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text, {bool isReq = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          children: isReq
              ? [
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGreen),
      ),
    );
  }

  Widget _buildCheckbox(String title, String key) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: selectedPaymentMethods.contains(key),
          activeColor: AppTheme.primaryGreen,
          onChanged: (val) {
            setState(() {
              if (val!) {
                selectedPaymentMethods.add(key);
              } else {
                selectedPaymentMethods.remove(key);
              }
            });
          },
        ),
        Text(title, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildCombinedImageGallery() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...existingPhotoUrls.asMap().entries.map(
            (entry) => _imageTile(
              Image.network(
                entry.value,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
              () => setState(() => existingPhotoUrls.removeAt(entry.key)),
            ),
          ),
          ...newImages.asMap().entries.map(
            (entry) => _imageTile(
              Image.file(
                File(entry.value.path),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
              () => setState(() => newImages.removeAt(entry.key)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageTile(Widget img, VoidCallback onDelete) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
