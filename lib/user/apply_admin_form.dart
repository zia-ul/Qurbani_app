import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<String> uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (govtIdFile == null ||
        businessProofFile == null ||
        bankProofFile == null ||
        farmPhotoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All documents are required")),
      );
      return;
    }

    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    // Upload documents
    final govtIdUrl = await uploadFile(
        govtIdFile!, "admin_docs/$uid/govt_id.jpg");
    final businessUrl = await uploadFile(
        businessProofFile!, "admin_docs/$uid/business_proof.jpg");
    final bankUrl = await uploadFile(
        bankProofFile!, "admin_docs/$uid/bank_proof.jpg");
    final farmUrl = await uploadFile(
        farmPhotoFile!, "admin_docs/$uid/farm_photo.jpg");

    await FirebaseFirestore.instance
        .collection('admin_applications')
        .doc(uid)
        .set({
      "userId": uid,
      "organizationName": orgController.text.trim(),
      "address": addressController.text.trim(),
      "experience": experienceController.text.trim(),
      "phone": phoneController.text.trim(),
      "documents": {
        "govtId": govtIdUrl,
        "businessProof": businessUrl,
        "bankProof": bankUrl,
        "farmPhoto": farmUrl,
      },
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      "role": "pending_admin",
    });

    setState(() => loading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Application submitted for review")),
    );

    Navigator.pop(context);
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
              child: Text(
                file == null ? "No file selected" : "File selected",
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await pickImage();
                if (picked != null) {
                  setState(() => onPick(picked));
                }
              },
              child: const Text("Upload"),
            )
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
        backgroundColor: Colors.green,
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
                validator: (v) =>
                    v!.isEmpty ? "Required field" : null,
              ),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Contact Number",
                ),
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
                decoration: const InputDecoration(
                  labelText: "Full Address",
                ),
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
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Submit Application"),
                    )
            ],
          ),
        ),
      ),
    );
  }
}
