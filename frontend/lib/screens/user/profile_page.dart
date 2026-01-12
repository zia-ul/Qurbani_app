import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qurbani/services/service_profile.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:qurbani/widgets/success_error_popup.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();

  // Backup data for cancel functionality
  String _oldName = "";
  String _oldPhone = "";
  String _oldAddress = "";
  String _oldDescription = "";

  String? _photoUrl;
  File? _selectedImage;

  final Color primaryGreen = const Color(0xff3D6B4E);

  final LinearGradient bgGradient = const LinearGradient(
    colors: [Color(0xFFE8E6D1), Color.fromARGB(255, 219, 210, 153)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      nameController.text = profile['name'] ?? '';
      emailController.text = profile['email'] ?? '';
      phoneController.text = profile['phone'] ?? '';
      addressController.text = profile['address'] ?? '';
      descriptionController.text = profile['description'] ?? '';
      _photoUrl = profile['photoUrl'];
    } catch (e) {
      print("Failed.......: $e");
      ToastUtils.showError('Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleEdit() {
    setState(() {
      if (!_isEditing) {
        // Backup current data
        _oldName = nameController.text;
        _oldPhone = phoneController.text;
        _oldAddress = addressController.text;
        _oldDescription = descriptionController.text;
        _isEditing = true;
      } else {
        // Cancel: Restore backup
        nameController.text = _oldName;
        phoneController.text = _oldPhone;
        addressController.text = _oldAddress;
        descriptionController.text = _oldDescription;
        _selectedImage = null;
        _isEditing = false;
      }
    });
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<String?> uploadToCloudinary(File image) async {
    const cloudName = 'dfezveorl';
    const uploadPreset = 'qurbani';
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final decoded = jsonDecode(await response.stream.bytesToString());
        return decoded['secure_url'];
      }
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
    }
    return null;
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (nameController.text.trim().length < 3) {
      ToastUtils.showError("Name must be at least 3 characters");
      return;
    }

    setState(() => _isLoading = true);
    String? imageUrl = _photoUrl;
    if (_selectedImage != null) {
      imageUrl = await uploadToCloudinary(_selectedImage!);
      if (imageUrl == null) {
        ToastUtils.showError("Image upload failed");
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      await ProfileService.updateProfile({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'description': descriptionController.text.trim(),
        'photoUrl': imageUrl,
      });

      setState(() {
        _photoUrl = imageUrl;
        _isEditing = false;
        _selectedImage = null;
      });
      ToastUtils.showSuccess("Profile updated successfully");
    } catch (e) {
      ToastUtils.showError("Update failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      backgroundColor: Colors.transparent,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeaderArea(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_isEditing)
                              _buildInfoCard(
                                Icons.business,
                                "Full Name",
                                nameController,
                                isNameField: true,
                              ),

                            // Phone Number Field
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: _cardDecoration(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: AbsorbPointer(
                                  absorbing: !_isEditing,
                                  child: IntlPhoneField(
                                    controller: phoneController,
                                    initialCountryCode: 'IN',
                                    keyboardType: TextInputType.phone,
                                    disableLengthCheck: false,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: _isEditing
                                          ? Colors.white
                                          : Colors.grey.shade50,
                                      labelText: 'Phone Number',
                                      labelStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    validator: (phone) {
                                      if (phone == null ||
                                          phone.number.isEmpty) {
                                        return 'Phone number is required';
                                      }
                                      if (!phone.isValidNumber()) {
                                        return 'Invalid phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ),

                            _buildInfoCard(
                              Icons.location_on,
                              "Address",
                              addressController,
                            ),
                            _buildDescriptionCard(),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description, color: Color(0xff537D4F), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Description",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isEditing)
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Description is required"
                        : null,
                    decoration: const InputDecoration(
                      hintText: "Enter details...",
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  )
                else
                  Text(
                    descriptionController.text.isEmpty
                        ? "No description provided."
                        : descriptionController.text,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    TextEditingController controller, {
    bool isNameField = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff537D4F), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isEditing)
                  TextFormField(
                    controller: controller,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return "$title is required";
                      if (isNameField && v.trim().length < 3)
                        return "Minimum 3 characters required";
                      return null;
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  )
                else
                  Text(
                    controller.text.isEmpty ? "Not set" : controller.text,
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isEditing ? pickProfileImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_photoUrl != null ? NetworkImage(_photoUrl!) : null)
                            as ImageProvider?,
                  child: (_photoUrl == null && _selectedImage == null)
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nameController.text.isEmpty ? "User Name" : nameController.text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _toggleEdit,
              icon: Icon(
                _isEditing ? Icons.close : Icons.edit,
                size: 20,
                color: _isEditing ? Colors.white : primaryGreen,
              ),
              label: Text(
                _isEditing ? "Cancel" : "Edit Profile",
                style: TextStyle(
                  color: _isEditing ? Colors.white : primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing
                    ? const Color(0xff9e1c1c)
                    : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isEditing ? saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff537D4F),
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Update Profile",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFD1C4A9).withOpacity(0.5)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
      ],
    );
  }
}
