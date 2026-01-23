import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';

class AddAnimalPage extends StatefulWidget {
  const AddAnimalPage({super.key});

  @override
  State<AddAnimalPage> createState() => _AddAnimalPageState();
}

class _AddAnimalPageState extends State<AddAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final descriptionController = TextEditingController();
  final breedController = TextEditingController();
  final priceController = TextEditingController();
  final sharesController = TextEditingController();
  final customAnimalTypeController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final ageController = TextEditingController();
  final deliveryFeeController = TextEditingController();
  final deliveryThresholdController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  String? selectedAnimalType;
  bool isLoading = false;
  bool isDeliveryPaid = false;

  // List<String> selectedPaymentMethods = ['cod', 'online'];
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  DateTime? lastBookedDate;
  final lastBookedDateController = TextEditingController();

  final Color lightBg = const Color(0xFFF9FBF9);

  @override
  void dispose() {
    lastBookedDateController.dispose();
    descriptionController.dispose();
    breedController.dispose();
    priceController.dispose();
    sharesController.dispose();
    customAnimalTypeController.dispose();
    heightController.dispose();
    weightController.dispose();
    ageController.dispose();
    deliveryFeeController.dispose();
    deliveryThresholdController.dispose();
    super.dispose();
  }

  Future<void> pickLastBookedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        lastBookedDate = picked;
        lastBookedDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> pickImages() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage(
      imageQuality: 80,
    );

    if (selectedImages.isNotEmpty) {
      setState(() {
        _images.addAll(selectedImages);
      });
    }
  }

  Future<List<String>> uploadImagesToCloudinary() async {
    const cloudName = 'dfezveorl';
    const uploadPreset = 'qurbani';
    List<String> uploadedUrls = [];

    for (final image in _images) {
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

  Future<void> addAnimal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for mandatory fields
    if (selectedAnimalType == null) {
      ToastUtils.showError('Animal Type is required');

      return;
    }
    if (lastBookedDate == null) {
      ToastUtils.showError('Last booked date is required');
      return;
    }

    if (priceController.text.trim().isEmpty) {
      ToastUtils.showError('Price is required');
      return;
    }
    // if (selectedPaymentMethods.isEmpty) {
    //   ToastUtils.showError('At least one payment method is required');

    //   return;
    // }
    // if (_images.isEmpty) {
    //   ToastUtils.showError('At least one image is required');

    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text("At least one image is required")),
    // );
    // return;
    // }

    final token = await _storage.read(key: "token");
    if (token == null) {
      ToastUtils.showError('Not authenticated');

      return;
    }

    setState(() => isLoading = true);

    try {
      final imageUrls = await uploadImagesToCloudinary();

      final body = {
        "animalType": selectedAnimalType == "Others"
            ? customAnimalTypeController.text.trim()
            : selectedAnimalType,
        "breed": breedController.text.trim(), //Optional
        "description": descriptionController.text.trim().isNotEmpty
            ? descriptionController.text.trim()
            : null, // Optional
        "price": double.parse(priceController.text),
        "age": ageController.text.trim().isNotEmpty
            ? ageController.text.trim()
            : null, // Optional
        "height": heightController.text.trim().isNotEmpty
            ? heightController.text.trim()
            : null, // Optional
        "weight": weightController.text.trim().isNotEmpty
            ? double.tryParse(weightController.text.trim())
            : null, // Optional
        "shares": int.parse(sharesController.text),
        // "paymentMethods": selectedPaymentMethods,
        "deliveryType": isDeliveryPaid ? "paid" : "free",
        "deliveryFee": isDeliveryPaid
            ? double.tryParse(deliveryFeeController.text) ?? 0
            : 0,
        "deliveryThreshold":
            double.tryParse(deliveryThresholdController.text) ??
            null, // Optional
        "images": imageUrls,
        // "lastBookedDate": lastBookedDate!.toIso8601String(),
      };

      final res = await http.post(
        Uri.parse("http://192.168.1.4:3000/api/animals"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (res.statusCode != 201) {
        throw Exception(
          jsonDecode(res.body)["message"] ?? "Failed to add animal",
        );
      }

      if (mounted) {
        ToastUtils.showSuccess("Animal added successfully");

        Navigator.pop(context);
      }
    } catch (e) {
      ToastUtils.showError("Failed to add animal: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: Text(
          "Add Animal",
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
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildCardContainer([
                      _buildLabel("Animal Type", isRequired: true),
                      DropdownButtonFormField<String>(
                        decoration: _inputDecoration("Select Type"),
                        items: ["Goat", "Buffalo", "Sheep", "Camel", "Others"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedAnimalType = val),
                        validator: (v) => v == null ? "Required" : null,
                      ),
                      if (selectedAnimalType == "Others") ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: customAnimalTypeController,
                          decoration: _inputDecoration(
                            "Enter Animal Type Name",
                          ),
                          validator: (v) =>
                              (selectedAnimalType == "Others" &&
                                  (v == null || v.isEmpty))
                              ? "Required"
                              : null,
                        ),
                      ],
                      const SizedBox(height: 15),
                      _buildLabel("Animal Breed", isRequired: false),
                      TextFormField(
                        controller: breedController,
                        decoration: _inputDecoration(
                          "Enter Breed (e.g. Beetal, Sahiwal)",
                        ),
                        // validator: (v) =>
                        //     (v == null || v.isEmpty) ? "Required" : null,
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
                                _buildLabel("Age", isRequired: false),
                                TextFormField(
                                  controller: ageController,
                                  decoration: _inputDecoration("e.g. 2 Years"),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Price", isRequired: true),
                                TextFormField(
                                  controller: priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration("Amount"),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? "Required"
                                      : null,
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
                                _buildLabel("Weight", isRequired: false),
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
                                _buildLabel("Height", isRequired: false),
                                TextFormField(
                                  controller: heightController,
                                  decoration: _inputDecoration("cm/ft"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]),

                    const SizedBox(height: 20),

                    _buildCardContainer([
                      _buildLabel("Shares Available", isRequired: true),
                      TextFormField(
                        controller: sharesController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          "Number of shares (1 for full animal)",
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? "Required" : null,
                      ),

                      const SizedBox(height: 15),

                      _buildLabel("Last Booking Date", isRequired: true),
                      TextFormField(
                        controller: lastBookedDateController,
                        readOnly: true,
                        decoration: _inputDecoration("Select date").copyWith(
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        onTap: pickLastBookedDate,
                      ),

                      const SizedBox(height: 20),
                      _buildLabel("Upload Gallery", isRequired: false),
                      GestureDetector(
                        onTap: pickImages,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                "Upload Photos",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_images.isNotEmpty) _buildImagePreview(),
                    ]),

                    // const SizedBox(height: 20),

                    // Container(
                    //   padding: const EdgeInsets.all(12),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white,
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(color: AppTheme.primaryGreen),
                    //   ),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       _buildLabel("Payment Method", isRequired: true),
                    //       const SizedBox(height: 8),
                    // CheckboxListTile(
                    //   value: selectedPaymentMethods.contains('cod'),
                    //   activeColor: AppTheme.primaryGreen,
                    //   title: const Text("Cash on Delivery"),
                    //   controlAffinity: ListTileControlAffinity.leading,
                    //   onChanged: (checked) {
                    //     setState(() {
                    //       if (checked == true) {
                    //         selectedPaymentMethods.add('cod');
                    //       } else {
                    //         selectedPaymentMethods.remove('cod');
                    //       }
                    //     });
                    //   },
                    // ),
                    // CheckboxListTile(
                    //   value: selectedPaymentMethods.contains('online'),
                    //   activeColor: AppTheme.primaryGreen,
                    //   title: const Text("Online Payment"),
                    //   controlAffinity: ListTileControlAffinity.leading,
                    //   onChanged: (checked) {
                    //     setState(() {
                    //       if (checked == true) {
                    //         selectedPaymentMethods.add('online');
                    //       } else {
                    //         selectedPaymentMethods.remove('online');
                    //       }
                    //     });
                    //   },
                    // ),
                    // if (selectedPaymentMethods.isEmpty)
                    //   const Padding(
                    //     padding: EdgeInsets.only(left: 12, top: 4),
                    //     child: Text(
                    //       "⚠ Select at least one payment method",
                    //       style: TextStyle(
                    //         color: Colors.red,
                    //         fontSize: 12,
                    //       ),
                    //     ),
                    //   ),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 8),

                    _buildCardContainer([
                      _buildLabel("Delivery Setup", isRequired: false),
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
                            onChanged: (val) =>
                                setState(() => isDeliveryPaid = val),
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
                        _buildLabel(
                          "Free Delivery Threshold (Optional)",
                          isSub: true,
                        ),
                        TextFormField(
                          controller: deliveryThresholdController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            "Free delivery if order > this amount",
                          ),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              const Color(0xFF5A916E),
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : addAnimal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            "Add Animal",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
      margin: const EdgeInsets.only(bottom: 5),
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

  Widget _buildLabel(
    String text, {
    bool isSub = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isSub ? Colors.grey[700] : Colors.black87,
            fontWeight: isSub ? FontWeight.normal : FontWeight.bold,
            fontSize: isSub ? 13 : 14,
          ),
          children: isRequired
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
      hintStyle: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length,
          itemBuilder: (context, i) => Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_images[i].path),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: 5,
                top: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
