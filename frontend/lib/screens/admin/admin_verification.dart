import 'package:Qurbani/services/service_profile.dart';
import 'package:Qurbani/services/upload_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

      AppLogger.info("Profile fetched successfully");
      setState(() {
        orgController.text = profile['organization_name'] ?? '';
        phoneController.text = profile['phone'] ?? '';
        addressController.text = profile['address'] ?? '';
        expController.text = "0"; // default experience
        fetchingProfile = false;
      });
    } catch (e, stack) {
      AppLogger.error("Failed to fetch admin profile", e, stack);
      setState(() => fetchingProfile = false);
      // ToastUtils.showError("Failed to fetch profile: $e");
    }
  }

  Future<XFile?> pickImage() async {
    AppLogger.debug("Opening image picker");
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (image != null) {
      AppLogger.info("Image selected: ${image.path}");
    } else {
      AppLogger.warning("Image picker cancelled by user");
    }

    return image;
  }

  Future<String?> upload(XFile? image) async {
    if (image == null) return null;

    AppLogger.debug("Uploading verification document", {"file": image.path});

    try {
      final url = await UploadService.uploadFile(
        image.path,
        context: 'admin_verification',
      );
      AppLogger.info("Verification document uploaded successfully");
      return url;
    } catch (e, stack) {
      AppLogger.error("Verification document upload error", e, stack);
      rethrow;
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (govtId == null ||
        businessProof == null ||
        bankProof == null ||
        farmPhoto == null) {
      AppLogger.warning(
        "Verification submit blocked: missing required documents",
      );
      ToastUtils.showError(
        "Please upload Government ID, Business Proof, Bank Proof, and Farm Photo.",
      );
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

      AppLogger.debug("Verification payload prepared");

      await AdminVerificationService.submitVerification(data);

      AppLogger.info("Admin verification submitted successfully");

      if (!mounted) return;

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
    } catch (e, stack) {
      AppLogger.error("Admin verification submission failed", e, stack);
      ToastUtils.showError(e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    orgController.dispose();
    phoneController.dispose();
    expController.dispose();
    addressController.dispose();
    super.dispose();
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
                  if (exp == null || exp < 1) {
                    return 'Minimum 1 year experience required';
                  }
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
                required: true,
                onPick: () async {
                  bankProof = await pickImage();
                  setState(() {});
                },
                onRemove: () => setState(() => bankProof = null),
              ),
              buildPicker(
                label: "Farm Photo",
                file: farmPhoto,
                required: true,
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
