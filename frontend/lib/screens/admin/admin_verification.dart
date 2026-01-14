import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani/services/admin_verification_service.dart';
import 'package:qurbani/screens/admin/admin_home_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qurbani/theme/theme.dart';

class AdminVerificationPage extends StatefulWidget {
  const AdminVerificationPage({super.key});

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController governmentIdController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool isLoading = false;
  List<XFile> _images = [];
  String? _verificationStatus;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _startStatusPolling();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    governmentIdController.dispose();
    addressController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final profile = await AdminVerificationService.getProfile();
      nameController.text = profile['name'] ?? '';
      emailController.text = profile['email'] ?? '';
      phoneController.text = profile['phone'] ?? '';
      addressController.text = profile['address'] ?? '';
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final status = await AdminVerificationService.getVerificationStatus();
        setState(() {
          _verificationStatus = status;
        });
        if (status == 'verified') {
          timer.cancel();
          _onVerified();
        }
      } catch (e) {
        // Ignore errors during polling
      }
    });
  }

  Future<void> _onVerified() async {
    // Optionally update role locally or fetch updated profile
    final profile = await AdminVerificationService.getProfile();
    final adminId = await _storage.read(
      key: 'userId',
    ); // Assuming you store userId
    final name = profile['name'] ?? 'Admin';

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHomePage(adminId: adminId!, name: name),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    setState(() => _images = images);
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
        final resStr = await response.stream.bytesToString();
        final resJson = jsonDecode(resStr);
        uploadedUrls.add(resJson['secure_url']);
      } else {
        throw Exception("Failed to upload ${image.name}");
      }
    }

    return uploadedUrls;
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one document")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final documentUrls = await uploadImagesToCloudinary();

      await AdminVerificationService.submitVerification({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'governmentId': governmentIdController.text.trim(),
        'address': addressController.text.trim(),
        'documentUrls': documentUrls,
      });

      setState(() {
        _verificationStatus = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification submitted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verificationStatus == 'pending') {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Admin Verification"),
          backgroundColor: AppTheme.primaryGreen,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(height: 20),
                Text(
                  "Thanks for submitting!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "We are still verifying your details. Kindly wait for approval.",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register as Admin"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Admin Verification",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Provide your details for identity verification with government-approved documents. All information will be securely stored.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: nameController,
                decoration: _inputDecoration("Full Name"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: emailController,
                readOnly: true,
                decoration: _inputDecoration("Email Address"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration("Phone Number"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Phone number is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: governmentIdController,
                decoration: _inputDecoration(
                  "Government ID (e.g., Aadhaar, Passport)",
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Government ID is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: addressController,
                decoration: _inputDecoration("Address"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Address is required" : null,
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _images.isEmpty
                      ? "Upload Documents"
                      : "${_images.length} file(s) selected",
                ),
                onPressed: _pickImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Submit Verification",
                          style: TextStyle(fontSize: 16),
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
