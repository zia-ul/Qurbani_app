import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qurbani/services/admin_application.dart';

class ApplyAdminFormPage extends StatefulWidget {
  const ApplyAdminFormPage({super.key});

  @override
  State<ApplyAdminFormPage> createState() => _ApplyAdminFormPageState();
}

class _ApplyAdminFormPageState extends State<ApplyAdminFormPage> {
  final _formKey = GlobalKey<FormState>();

  final orgController = TextEditingController();
  final addressController = TextEditingController();
  final experienceController = TextEditingController();
  final phoneController = TextEditingController();

  File? govtIdFile;
  File? businessProofFile;
  File? bankProofFile;
  File? farmPhotoFile;

  bool loading = false;

  final picker = ImagePicker();

  Future<File?> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }

  // Future<String> uploadFile(File file, String path) async {
  //   final ref = FirebaseStorage.instance.ref(path);
  //   await ref.putFile(file);
  //   return await ref.getDownloadURL();
  // }

  Future<void> submitApplication() async {
  if (!_formKey.currentState!.validate()) return;

  if ([govtIdFile, businessProofFile, bankProofFile, farmPhotoFile].contains(null)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("All documents required")));
    return;
  }

  setState(() => loading = true);

  try {
    await AdminApplicationService.apply(
      organizationName: orgController.text.trim(),
      phone: phoneController.text.trim(),
      experience: experienceController.text.trim(),
      address: addressController.text.trim(),
      govtId: govtIdFile!,
      businessProof: businessProofFile!,
      bankProof: bankProofFile!,
      farmPhoto: farmPhotoFile!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Application submitted for review")),
    );

    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
  } finally {
    setState(() => loading = false);
  }
}


  Widget documentPicker(String title, File? file, Function(File) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(file == null ? "No file selected" : "File selected"),
            ),
            TextButton(
              onPressed: () async {
                final picked = await pickImage();
                if (picked != null) {
                  setState(() => onPick(picked));
                }
              },
              child: const Text("Upload"),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Application"),
        backgroundColor: Color(0xff537D4F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: orgController,
                decoration: const InputDecoration(
                  labelText: "Organization / Farm Name",
                ),
                validator: (v) => v!.isEmpty ? "Required field" : null,
              ),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Contact Number"),
                validator: (v) =>
                    v!.length < 10 ? "Invalid phone number" : null,
              ),

              TextFormField(
                controller: experienceController,
                decoration: const InputDecoration(
                  labelText: "Years of Experience",
                ),
                keyboardType: TextInputType.number,
              ),

              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Full Address"),
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              documentPicker(
                "Government ID",
                govtIdFile,
                (f) => govtIdFile = f,
              ),
              documentPicker(
                "Business / Trust Proof",
                businessProofFile,
                (f) => businessProofFile = f,
              ),
              documentPicker(
                "Bank Proof",
                bankProofFile,
                (f) => bankProofFile = f,
              ),
              documentPicker(
                "Farm / Facility Photo",
                farmPhotoFile,
                (f) => farmPhotoFile = f,
              ),

              const SizedBox(height: 30),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: submitApplication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff537D4F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Submit Application"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
