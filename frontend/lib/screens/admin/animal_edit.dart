import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/theme/theme.dart';
import 'dart:convert';
import 'package:Qurbani/widgets/primary_btn.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnimalEditPage extends StatefulWidget {
  final String animalId;
  final String orderId;

  const AnimalEditPage({
    super.key,
    required this.animalId,
    required this.orderId,
  });

  @override
  State<AnimalEditPage> createState() => _AnimalEditPageState();
}

class _AnimalEditPageState extends State<AnimalEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  static final String? _baseUrl = dotenv.env['BASE_URL'];

  final descriptionController = TextEditingController();
  final breedController = TextEditingController();
  final priceController = TextEditingController();
  final ageController = TextEditingController();
  final sharesController = TextEditingController();
  final animalTypeController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final deliveryFeeController = TextEditingController();
  final deliveryThresholdController = TextEditingController();
  final barcodeController = TextEditingController();

  bool isLoading = true;
  bool isUpdating = false;
  List<String> existingPhotoUrls = [];
  List<XFile> newImages = [];
  final ImagePicker _picker = ImagePicker();
  List<String> selectedPaymentMethods = [];
  String? selectedAnimalType;
  String? selectedDeliveryType; // add this

  // When loading animal details
  // selectedDeliveryType = data['delivery_type'] ?? 'Free';
  final Color lightBg = const Color(0xFFF9FBF9);
  bool get isDeliveryPaid => selectedDeliveryType?.toLowerCase() == "paid";

  @override
  void initState() {
    super.initState();
    print("order id being printed......$widget.orderId");
    _loadAnimalDetails();
  }

  void generateBarcode() {
    // combine animalId + timestamp for uniqueness
    final barcode =
        "${widget.animalId}-${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      barcodeController.text = barcode;
    });
  }

  bool _hasValue(TextEditingController c) {
    return c.text.trim().isNotEmpty;
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

      print("data on fronent...animal edit: $data");

      // from animals table
      animalTypeController.text = data['animal_type'] ?? '';
      breedController.text = data['details_breed'] ?? data['breed'] ?? '';
      descriptionController.text =
          data['details_description'] ?? data['description'] ?? '';
      ageController.text = data['details_age'] ?? '';
      heightController.text = data['details_height'] ?? '';
      weightController.text = data['details_weight'] ?? '';
      priceController.text = data['price']?.toString() ?? '';
      sharesController.text = data['shares']?.toString() ?? '';

      // animal_details specific
      barcodeController.text = data['barcode'] ?? '';
      final meatWeight = data['meat_weight'];
      final bodyPartsDesc = data['body_parts_description'];
      final qurbaniDate = data['qurbani_datetime'];

      // photos (prefer animal_details if present)
      // Robust handling of details_photo_urls
      final photoUrlsRaw =
          data['details_photo_urls'] ?? data['photo_urls'] ?? [];

      if (photoUrlsRaw is String) {
        existingPhotoUrls = photoUrlsRaw.contains(',')
            ? photoUrlsRaw.split(',').map((e) => e.trim()).toList()
            : [photoUrlsRaw];
      } else if (photoUrlsRaw is List) {
        existingPhotoUrls = List<String>.from(photoUrlsRaw);
      } else {
        existingPhotoUrls = [];
      }

      // selectedPaymentMethods = List<String>.from(
      //   jsonDecode(data['payment_methods'] ?? "[]"),
      // );

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

    final confirmed = await _showConfirmationDialog();

    if (!confirmed) {
      // User clicked cancel → allow editing
      return;
    }

    // User confirmed → lock in
    await _submitAnimalUpdate();
  }

  Future<void> _submitAnimalUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isUpdating = true);

    try {
      final token = await _storage.read(key: "token");

      final newUrls = await _uploadNewImages();
      final allImages = [...existingPhotoUrls, ...newUrls];

      final res = await http.post(
        Uri.parse("$_baseUrl/animals/${widget.animalId}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "orderId": widget.orderId,
          // "animalType": selectedAnimalType ?? animalTypeController.text,
          "breed": breedController.text,
          "description": descriptionController.text,
          // "price": double.parse(priceController.text),
          "age": ageController.text,
          "height": heightController.text,
          "weight": weightController.text,
          // "shares": int.parse(sharesController.text),
          "photoUrls": allImages,
          // "deliveryType": selectedDeliveryType ?? "Free",
          // "deliveryFee": double.parse(deliveryFeeController.text),
          // "deliveryThreshold": isDeliveryPaid
          // ? double.tryParse(deliveryThresholdController.text) ?? null
          // : null,
          "barcode": barcodeController.text,
        }),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ToastUtils.showSuccess('Animal updated successfully');
        Navigator.pop(context);
      } else {
        print(res.body); // 👈 debug help
        throw res.body;
      }
    } catch (e) {
      ToastUtils.showError("Error: $e");
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
                _buildLabel("Animal Type"),
                _readOnlyField(
                  controller: animalTypeController,
                  label: "Animal Type",
                ),

                const SizedBox(height: 15),

                // const SizedBox(height: 15),
                _buildLabel("Animal Breed", isReq: true),
                TextFormField(
                  controller: breedController,
                  enabled: !_hasValue(breedController),
                  decoration: _inputDecoration("e.g. Sahiwal").copyWith(
                    fillColor: _hasValue(breedController)
                        ? Colors.grey[100]
                        : Colors.grey[50],
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),

                const SizedBox(height: 15),
                _buildLabel("Description (Optional)", isReq: false),
                TextFormField(
                  controller: descriptionController,
                  enabled: !_hasValue(descriptionController),
                  maxLines: 3,
                  decoration: _inputDecoration("Appearance details...")
                      .copyWith(
                        fillColor: _hasValue(descriptionController)
                            ? Colors.grey[100]
                            : Colors.grey[50],
                      ),
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
                            enabled: !_hasValue(heightController),
                            decoration: _inputDecoration("cm / ft").copyWith(
                              fillColor: _hasValue(heightController)
                                  ? Colors.grey[100]
                                  : Colors.grey[50],
                            ),
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
                          _buildLabel("Price", isReq: true),
                          TextFormField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            readOnly: true, // 🔒 lock editing
                            enabled: false, // 🚫 disable interaction
                            decoration: _inputDecoration("0.00").copyWith(
                              fillColor: Colors.grey[100], // visual cue
                            ),
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
                            enabled: !_hasValue(weightController),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("kg").copyWith(
                              fillColor: _hasValue(weightController)
                                  ? Colors.grey[100]
                                  : Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Age"),
                          TextFormField(
                            controller: ageController,
                            enabled: !_hasValue(weightController),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("years").copyWith(
                              fillColor: _hasValue(weightController)
                                  ? Colors.grey[100]
                                  : Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              _buildLabel("Shares Available"),
              _readOnlyField(
                controller: sharesController,
                label: "Total Shares",
              ),

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
                _buildLabel("Barcode", isReq: true),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: barcodeController,
                        readOnly: _hasValue(
                          barcodeController,
                        ), // disable if already has value
                        enabled: !_hasValue(
                          barcodeController,
                        ), // visually greys out
                        decoration: _inputDecoration("Generated barcode")
                            .copyWith(
                              fillColor: _hasValue(barcodeController)
                                  ? Colors.grey[100]
                                  : Colors.grey[50],
                            ),
                        validator: (v) =>
                            v!.isEmpty ? "Generate barcode first" : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _hasValue(barcodeController)
                          ? null // disable button if barcode exists
                          : generateBarcode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 45),
                      ),
                      child: const Text("Generate"),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 20),

              _buildCardContainer([
                _buildLabel("Delivery Setup", isReq: true),

                // Toggle Free / Paid
                Row(
                  children: [
                    Text(
                      "Free Delivery",
                      style: TextStyle(
                        color: !isDeliveryPaid
                            ? AppTheme.primaryGreen
                            : Colors.black54,
                      ),
                    ),
                    Switch(
                      value: isDeliveryPaid,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) {
                        setState(() {
                          selectedDeliveryType = val ? "Paid" : "Free";

                          // Clear fee and threshold if switched to Free
                          if (!val) {
                            deliveryFeeController.clear();
                            deliveryThresholdController.clear();
                          }
                        });
                      },
                    ),
                    Text(
                      "Paid Delivery",
                      style: TextStyle(
                        color: isDeliveryPaid
                            ? AppTheme.primaryGreen
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),

                // Paid delivery details
                if (isDeliveryPaid) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: deliveryFeeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Delivery Fee Amount"),
                    validator: (v) =>
                        (isDeliveryPaid && (v == null || v.isEmpty))
                        ? "Required for paid delivery"
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: deliveryThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      "Free delivery if order > this amount",
                    ),
                  ),
                ],
              ]),

              const SizedBox(height: 15),
              // _buildCardContainer([
              //   _buildLabel("Payment Method", isReq: true),
              //   Row(
              //     children: [
              //       _buildCheckbox("COD", 'cod'),
              //       _buildCheckbox("Online", 'online'),
              //     ],
              //   ),
              // ]),
              // const SizedBox(height: 30),
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

  TextFormField _readOnlyField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: false,
      decoration: _inputDecoration(label).copyWith(fillColor: Colors.grey[100]),
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

  // Widget _buildCheckbox(String title, String key) {
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Checkbox(
  //         value: selectedPaymentMethods.contains(key),
  //         activeColor: AppTheme.primaryGreen,
  //         onChanged: (val) {
  //           setState(() {
  //             if (val!) {
  //               selectedPaymentMethods.add(key);
  //             } else {
  //               selectedPaymentMethods.remove(key);
  //             }
  //           });
  //         },
  //       ),
  //       Text(title, style: const TextStyle(fontSize: 13)),
  //     ],
  //   );
  // }

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

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          children: [
            TextSpan(
              text: value.isEmpty ? "—" : value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Confirm Animal Details",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _confirmRow("Breed", breedController.text),
                    _confirmRow("Description", descriptionController.text),
                    _confirmRow("Age", ageController.text),
                    _confirmRow("Height", heightController.text),
                    _confirmRow("Weight", weightController.text),
                    _confirmRow("Barcode", barcodeController.text),
                    const SizedBox(height: 12),
                    const Text(
                      "⚠ These details won’t be editable again.\nKindly confirm before proceeding.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
