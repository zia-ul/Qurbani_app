import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  String _uid = '';

  /// Store original values (for cancel)
  String _originalName = '';
  String _originalEmail = '';
  String _originalAddress = '';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  /// 🔥 LOAD USER PROFILE FROM FIRESTORE
  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        _originalName = data['name'] ?? '';
        _originalEmail = data['email'] ?? '';
        _originalAddress = data['address'] ?? '';

        nameController.text = _originalName;
        emailController.text = _originalEmail;
        addressController.text = _originalAddress;
      }
    } catch (e) {
      debugPrint("Load profile error: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// 💾 UPDATE PROFILE IN FIRESTORE
  Future<void> updateProfile() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
      });

      _originalName = nameController.text;
      _originalEmail = emailController.text;
      _originalAddress = addressController.text;

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }

    _isSaving = false;
  }

  /// ❌ CANCEL EDIT
  void cancelEdit() {
    nameController.text = _originalName;
    emailController.text = _originalEmail;
    addressController.text = _originalAddress;

    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                cancelEdit();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person,
                          size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    _buildField(
                      controller: nameController,
                      label: "Full Name",
                      enabled: _isEditing,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter name" : null,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: emailController,
                      label: "Email",
                      enabled: false, // 🔒 email read-only
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: addressController,
                      label: "Address",
                      enabled: _isEditing,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 25),

                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text("Save Changes"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              updateProfile();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// 🔹 INPUT FIELD BUILDER
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool enabled = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }
}
