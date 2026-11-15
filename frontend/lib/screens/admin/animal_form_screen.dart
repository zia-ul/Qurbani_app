import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:Qurbani/widgets/primary_btn.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

/// Unified Animal Form Screen
/// Handles both:
/// 1. Create Mode: animalId == null (replaces AddAnimalPage)
/// 2. Edit Mode: animalId != null (replaces AnimalEditPage)
class AnimalFormScreen extends StatefulWidget {
  final String? animalId;
  final String? orderId;

  /// Optional mock hook for unit/widget testing
  static Future<Map<String, dynamic>> Function(String animalId, String? orderId)? mockLoadDetails;

  const AnimalFormScreen({
    super.key,
    this.animalId,
    this.orderId,
  });

  bool get isEdit => animalId != null && animalId!.isNotEmpty;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  static final String _baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000/api';

  // Controllers
  final descriptionController = TextEditingController();
  final breedController = TextEditingController();
  final sharesController = TextEditingController();
  final customAnimalTypeController = TextEditingController();
  final animalTypeController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final ageController = TextEditingController();
  final barcodeController = TextEditingController();

  String? selectedAnimalType;
  bool isLoading = false;
  bool isSubmitting = false;

  // Images
  List<String> existingPhotoUrls = [];
  final List<XFile> newImages = [];

  final Color lightBg = const Color(0xFFF9FBF9);

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loadAnimalDetails();
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    breedController.dispose();
    sharesController.dispose();
    customAnimalTypeController.dispose();
    animalTypeController.dispose();
    heightController.dispose();
    weightController.dispose();
    ageController.dispose();
    barcodeController.dispose();
    super.dispose();
  }

  bool _hasValue(TextEditingController c) => c.text.trim().isNotEmpty;

  void generateBarcode() {
    final barcode = "${widget.animalId}-${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      barcodeController.text = barcode;
    });
  }

  Future<void> _loadAnimalDetails() async {
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> data;

      if (AnimalFormScreen.mockLoadDetails != null) {
        data = await AnimalFormScreen.mockLoadDetails!(widget.animalId!, widget.orderId);
      } else {
        final token = await _storage.read(key: "token");
        if (token == null) {
          AppLogger.warning("Token missing while loading animal details");
          setState(() => isLoading = false);
          return;
        }

        final uri = Uri.parse("$_baseUrl/animals/${widget.animalId}").replace(
          queryParameters: {
            if (widget.orderId != null) 'orderId': widget.orderId!,
          },
        );

        final res = await http.get(
          uri,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );

        if (res.statusCode != 200) {
          AppLogger.error("Failed to load animal details", res.body);
          setState(() => isLoading = false);
          return;
        }

        data = jsonDecode(res.body);
      }

      animalTypeController.text = data['animal_type'] ?? '';
      selectedAnimalType = data['animal_type'];
      breedController.text = data['details_breed'] ?? data['breed'] ?? '';
      descriptionController.text = data['details_description'] ?? data['description'] ?? '';
      ageController.text = data['details_age'] ?? '';
      heightController.text = data['details_height'] ?? '';
      weightController.text = data['details_weight']?.toString() ?? '';
      sharesController.text = data['shares']?.toString() ?? '';
      barcodeController.text = data['barcode'] ?? '';

      final raw = data['details_photo_urls'] ?? data['photo_urls'];
      List<String> parsedUrls = [];
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            parsedUrls = decoded.cast<String>();
          } else if (raw.startsWith('http')) {
            parsedUrls = [raw];
          }
        } catch (_) {
          if (raw.startsWith('http')) parsedUrls = [raw];
        }
      } else if (raw is List) {
        parsedUrls = raw.cast<String>();
      }

      existingPhotoUrls = parsedUrls;
      setState(() => isLoading = false);
    } catch (e, stack) {
      AppLogger.error("Exception loading animal details", e, stack);
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImages() async {
    final List<XFile> selected = await _picker.pickMultiImage(imageQuality: 80);
    if (selected.isNotEmpty) {
      setState(() {
        newImages.addAll(selected);
      });
    }
  }

  Future<List<String>> _uploadNewImagesToCloudinary() async {
    const cloudName = 'dfezveorl';
    const uploadPreset = 'qurbani';
    List<String> uploadedUrls = [];

    for (final image in newImages) {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
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

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Details"),
            content: const Text(
              "Are you sure the details entered are correct?\n\nOnce submitted, you will not be able to edit this animal again.",
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
          ),
        ) ??
        false;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      AppLogger.warning("Form validation failed");
      return;
    }

    if (!widget.isEdit && selectedAnimalType == null) {
      ToastUtils.showError('Animal Type is required');
      return;
    }

    if (widget.isEdit) {
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) return;
    }

    final token = await _storage.read(key: "token");
    if (token == null) {
      ToastUtils.showError('Not authenticated');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final uploadedUrls = await _uploadNewImagesToCloudinary();

      if (widget.isEdit) {
        // Edit flow
        final allImages = [...existingPhotoUrls, ...uploadedUrls];
        final body = {
          if (widget.orderId != null) "orderId": widget.orderId,
          "breed": breedController.text.trim(),
          "description": descriptionController.text.trim(),
          "age": ageController.text.trim(),
          "height": heightController.text.trim(),
          "weight": weightController.text.trim(),
          "photoUrls": allImages,
          "barcode": barcodeController.text.trim(),
        };

        final res = await http.post(
          Uri.parse("$_baseUrl/animals/${widget.animalId}"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode(body),
        );

        if (res.statusCode == 200) {
          if (!mounted) return;
          ToastUtils.showSuccess('Animal updated successfully');
          Navigator.pop(context, true);
        } else {
          throw res.body;
        }
      } else {
        // Create flow
        final body = {
          "animalType": selectedAnimalType == "Others"
              ? customAnimalTypeController.text.trim()
              : selectedAnimalType,
          "breed": breedController.text.trim(),
          "description": descriptionController.text.trim().isNotEmpty
              ? descriptionController.text.trim()
              : null,
          "age": ageController.text.trim().isNotEmpty ? ageController.text.trim() : null,
          "height": heightController.text.trim().isNotEmpty ? heightController.text.trim() : null,
          "weight": weightController.text.trim().isNotEmpty
              ? double.tryParse(weightController.text.trim())
              : null,
          "shares": int.parse(sharesController.text.trim()),
          "images": uploadedUrls,
        };

        final res = await http.post(
          Uri.parse("$_baseUrl/animals"),
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

        if (!mounted) return;
        ToastUtils.showSuccess("Animal added successfully");
        Navigator.pop(context, true);
      }
    } catch (e) {
      ToastUtils.showError("Error: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
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

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          children: isRequired
              ? [const TextSpan(text: " *", style: TextStyle(color: Colors.red))]
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? "Edit Animal Details" : "Add Animal";

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.bgGradientEnd,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.primaryGreen),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Card 1: Animal Type & Breed
                    _buildCardContainer([
                      _buildLabel("Animal Type", isRequired: !widget.isEdit),
                      if (widget.isEdit)
                        TextFormField(
                          controller: animalTypeController,
                          enabled: false,
                          decoration: _inputDecoration("Animal Type").copyWith(
                            fillColor: Colors.grey[200],
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration("Select Type"),
                          items: ["Goat", "Buffalo", "Sheep", "Camel", "Others"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setState(() => selectedAnimalType = val),
                          validator: (v) => v == null ? "Required" : null,
                        ),
                        if (selectedAnimalType == "Others") ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: customAnimalTypeController,
                            decoration: _inputDecoration("Enter Animal Type Name"),
                            validator: (v) =>
                                (selectedAnimalType == "Others" && (v == null || v.isEmpty))
                                    ? "Required"
                                    : null,
                          ),
                        ],
                      ],
                      const SizedBox(height: 15),
                      _buildLabel("Animal Breed", isRequired: widget.isEdit),
                      TextFormField(
                        controller: breedController,
                        enabled: !widget.isEdit || !_hasValue(breedController),
                        decoration: _inputDecoration("e.g. Sahiwal").copyWith(
                          fillColor: (widget.isEdit && _hasValue(breedController))
                              ? Colors.grey[100]
                              : Colors.grey[50],
                        ),
                        validator: (v) {
                          if (widget.isEdit && (v == null || v.isEmpty)) {
                            return "Required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildLabel("Description (Optional)", isRequired: false),
                      TextFormField(
                        controller: descriptionController,
                        enabled: !widget.isEdit || !_hasValue(descriptionController),
                        maxLines: 3,
                        decoration: _inputDecoration("Appearance details...").copyWith(
                          fillColor: (widget.isEdit && _hasValue(descriptionController))
                              ? Colors.grey[100]
                              : Colors.grey[50],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Card 2: Age, Height, Weight
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
                                  enabled: !widget.isEdit || !_hasValue(ageController),
                                  decoration: _inputDecoration("e.g. 2 Years").copyWith(
                                    fillColor: (widget.isEdit && _hasValue(ageController))
                                        ? Colors.grey[100]
                                        : Colors.grey[50],
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
                                _buildLabel("Weight", isRequired: widget.isEdit),
                                TextFormField(
                                  controller: weightController,
                                  keyboardType: TextInputType.number,
                                  enabled: !widget.isEdit || !_hasValue(weightController),
                                  decoration: _inputDecoration("kg").copyWith(
                                    fillColor: (widget.isEdit && _hasValue(weightController))
                                        ? Colors.grey[100]
                                        : Colors.grey[50],
                                  ),
                                  validator: (v) {
                                    if (widget.isEdit && (v == null || v.isEmpty)) {
                                      return "Required";
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Height", isRequired: widget.isEdit),
                                TextFormField(
                                  controller: heightController,
                                  enabled: !widget.isEdit || !_hasValue(heightController),
                                  decoration: _inputDecoration("cm / ft").copyWith(
                                    fillColor: (widget.isEdit && _hasValue(heightController))
                                        ? Colors.grey[100]
                                        : Colors.grey[50],
                                  ),
                                  validator: (v) {
                                    if (widget.isEdit && (v == null || v.isEmpty)) {
                                      return "Required";
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Card 3: Shares (Create Mode) or Barcode (Edit Mode)
                    if (!widget.isEdit)
                      _buildCardContainer([
                        _buildLabel("Shares Available", isRequired: true),
                        TextFormField(
                          controller: sharesController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration("Number of shares (1 for full animal)"),
                          validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                        ),
                      ])
                    else
                      _buildCardContainer([
                        _buildLabel("Animal Barcode", isRequired: true),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: barcodeController,
                                enabled: !_hasValue(barcodeController),
                                decoration: _inputDecoration("Scan or generate").copyWith(
                                  fillColor: _hasValue(barcodeController)
                                      ? Colors.grey[100]
                                      : Colors.grey[50],
                                ),
                                validator: (v) => v!.isEmpty ? "Barcode required" : null,
                              ),
                            ),
                            if (!_hasValue(barcodeController)) ...[
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: generateBarcode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: const Text("Generate"),
                              ),
                            ],
                          ],
                        ),
                      ]),

                    const SizedBox(height: 20),

                    // Card 4: Images
                    _buildCardContainer([
                      _buildLabel("Animal Photos", isRequired: false),
                      if (existingPhotoUrls.isNotEmpty) ...[
                        const Text("Existing Photos:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: existingPhotoUrls.length,
                            itemBuilder: (_, i) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(existingPhotoUrls[i]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (newImages.isNotEmpty) ...[
                        const Text("New Photos:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: newImages.length,
                            itemBuilder: (_, i) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(newImages[i].path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: pickImages,
                        icon: const Icon(Icons.add_photo_alternate, color: AppTheme.primaryGreen),
                        label: const Text("Select Photos", style: TextStyle(color: AppTheme.primaryGreen)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 30),

                    // Submit Button
                    PrimaryButton(
                      text: widget.isEdit ? "Update Animal Details" : "Add Animal",
                      height: 50,
                      isLoading: isSubmitting,
                      onPressed: _submitForm,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
