import 'dart:convert';
import 'package:Qurbani/services/service_profile.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:Qurbani/drawer.dart';
import 'package:Qurbani/screens/admin/pending_admin.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import '../../services/admin_verification_service.dart';

class AdminVerificationPage extends StatefulWidget {
  final String id;
  final String name;
  final String role;
  final String? verification;

  const AdminVerificationPage({
    super.key,
    required this.id,
    required this.name,
    required this.role,
    required this.verification,
  });

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  final _formKey = GlobalKey<FormState>();

  final orgController = TextEditingController();
  final phoneController = TextEditingController();
  final expController = TextEditingController(text: "0"); // default experience
  final addressController = TextEditingController();

  XFile? govtId;
  XFile? businessProof;
  XFile? bankProof;
  XFile? farmPhoto;

  bool loading = false;
  bool fetchingProfile = true;

  String _fileName(XFile file) => file.path.split('/').last;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      setState(() {
        orgController.text = profile['organization_name'] ?? '';
        phoneController.text = profile['phone'] ?? '';
        addressController.text = profile['address'] ?? '';
        expController.text = "0"; // default experience
        fetchingProfile = false;
      });
    } catch (e) {
      setState(() => fetchingProfile = false);
      ToastUtils.showError("Failed to fetch profile: $e");
    }
  }

  Future<XFile?> pickImage() async {
    return await ImagePicker().pickImage(source: ImageSource.gallery);
  }

  Future<String?> upload(XFile? image) async {
    if (image == null) return null;
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse(
                'https://api.cloudinary.com/v1_1/dfezveorl/image/upload',
              ),
            )
            ..fields['upload_preset'] = 'qurbani'
            ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode != 200) throw Exception("Image upload failed");
      return jsonDecode(body)['secure_url'];
    } catch (e) {
      // debugPrint("Upload error: $e");
      rethrow;
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (govtId == null || businessProof == null) {
      ToastUtils.showError("Please upload required documents");
      return;
    }

    setState(() => loading = true);

    try {
      final data = {
        "organization_name": orgController.text.trim(),
        "phone": phoneController.text.trim(),
        "experience": expController.text.trim(),
        "address": addressController.text.trim(),
        "govt_id_url": await upload(govtId),
        "business_proof_url": await upload(businessProof),
        "bank_proof_url": await upload(bankProof),
        "farm_photo_url": await upload(farmPhoto),
      };

      await AdminVerificationService.submitVerification(data);

      ToastUtils.showSuccess("Verification submitted");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PendingAdminScreen(
            id: widget.id,
            name: widget.name,
            role: widget.role,
            verification: "pending",
          ),
        ),
      );
    } catch (e) {
      ToastUtils.showError(e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fetchingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Register as Admin")),
      drawer: MasterDrawer(id: widget.id, name: widget.name, role: widget.role),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Organization Name
              TextFormField(
                controller: orgController,
                decoration: const InputDecoration(
                  labelText: "Organization Name",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Phone with country code
              IntlPhoneField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
                initialCountryCode: 'IN',
                onChanged: (phone) =>
                    phoneController.text = phone.completeNumber,
                validator: (phone) {
                  if (phone == null || phone.number.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Experience
              TextFormField(
                controller: expController,
                decoration: const InputDecoration(
                  labelText: "Experience (years)",
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final exp = int.tryParse(v);
                  if (exp == null || exp < 1)
                    return 'Minimum 1 year experience required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Address"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Document pickers
              buildPicker(
                label: "Government ID",
                file: govtId,
                required: true,
                onPick: () async {
                  govtId = await pickImage();
                  setState(() {});
                },
                onRemove: () => setState(() => govtId = null),
              ),
              buildPicker(
                label: "Business Proof",
                file: businessProof,
                required: true,
                onPick: () async {
                  businessProof = await pickImage();
                  setState(() {});
                },
                onRemove: () => setState(() => businessProof = null),
              ),
              buildPicker(
                label: "Bank Proof",
                file: bankProof,
                required: false,
                onPick: () async {
                  bankProof = await pickImage();
                  setState(() {});
                },
                onRemove: () => setState(() => bankProof = null),
              ),
              buildPicker(
                label: "Farm Photo",
                file: farmPhoto,
                required: false,
                onPick: () async {
                  farmPhoto = await pickImage();
                  setState(() {});
                },
                onRemove: () => setState(() => farmPhoto = null),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Submit Verification"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPicker({
    required String label,
    required XFile? file,
    required bool required,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: required && file == null
              ? AppTheme.warningRed
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: required && file == null
                ? AppTheme.warningRed
                : Colors.black,
          ),
        ),
        subtitle: file != null
            ? Text(_fileName(file), style: const TextStyle(fontSize: 12))
            : required
            ? const Text(
                "Required",
                style: TextStyle(color: AppTheme.warningRed, fontSize: 12),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file != null)
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.warningRed),
                onPressed: onRemove,
              ),
            IconButton(icon: const Icon(Icons.upload), onPressed: onPick),
          ],
        ),
      ),
    );
  }
}
