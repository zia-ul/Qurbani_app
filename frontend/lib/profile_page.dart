import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/services/service_profile.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isAdmin = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  DateTime? _orderDeadline;

  // Backup data for cancel functionality
  String _oldName = "";
  String _oldPhone = "";
  String _oldAddress = "";
  String _oldDescription = "";
  DateTime? _oldDeadline;
  String? _oldPhotoUrl;

  String? _photoUrl;
  File? _selectedImage;

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
      if (!mounted) return;

      setState(() {
        nameController.text = profile['name'] ?? '';
        emailController.text = profile['email'] ?? '';
        phoneController.text = profile['phone'] ?? '';
        addressController.text = profile['address'] ?? '';
        descriptionController.text = profile['description'] ?? '';
        _photoUrl = profile['photo_url'];
        _isAdmin = profile['isAdmin'] ?? false;

        if (profile['order_deadline'] != null) {
          _orderDeadline = DateTime.tryParse(profile['order_deadline']);
        }

        _isLoading = false;
      });
    } catch (e) {
      ToastUtils.showError('Failed to load profile');
      setState(() => _isLoading = false);
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
        _oldDeadline = _orderDeadline;
        _oldPhotoUrl = _photoUrl;
        _isEditing = true;
      } else {
        // Cancel: Restore backup
        nameController.text = _oldName;
        phoneController.text = _oldPhone;
        addressController.text = _oldAddress;
        descriptionController.text = _oldDescription;
        _orderDeadline = _oldDeadline;
        _photoUrl = _oldPhotoUrl;
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

  Future<void> selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _orderDeadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _orderDeadline = picked);
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
    } catch (e) {}
    return null;
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (nameController.text.trim().length < 3) {
      ToastUtils.showError("Name must be at least 3 characters");
      return;
    }

    if (_isAdmin &&
        _orderDeadline != null &&
        _orderDeadline!.isBefore(DateTime.now())) {
      ToastUtils.showError("Deadline must be in the future");
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
        'orderDeadline': _orderDeadline?.toIso8601String().split(
          'T',
        )[0], // YYYY-MM-DD
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
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              )
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
                                          ? AppTheme.bgGradientEnd
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

                            // Deadline for Admins
                            if (_isAdmin) ...[
                              const SizedBox(height: 12),
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: _cardDecoration(),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: AppTheme.primaryGreen,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Order Deadline",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_isEditing)
                                            GestureDetector(
                                              onTap: selectDeadline,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _orderDeadline != null
                                                      ? DateFormat(
                                                          'yyyy-MM-dd',
                                                        ).format(
                                                          _orderDeadline!,
                                                        )
                                                      : 'Select Deadline',
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              _orderDeadline != null
                                                  ? DateFormat(
                                                      'yyyy-MM-dd',
                                                    ).format(_orderDeadline!)
                                                  : "No deadline set",
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

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
          const Icon(Icons.description, color: AppTheme.primaryGreen, size: 24),
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
          Icon(icon, color: AppTheme.primaryGreen, size: 24),
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
    ImageProvider? imageProvider;

    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_photoUrl!);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 20),
      decoration: const BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditing ? pickProfileImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: AppTheme.bgGradientEnd,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                color: _isEditing
                    ? AppTheme.bgGradientEnd
                    : AppTheme.primaryGreen,
              ),
              label: Text(
                _isEditing ? "Cancel" : "Edit Profile",
                style: TextStyle(
                  color: _isEditing
                      ? AppTheme.bgGradientEnd
                      : AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing
                    ? const Color(0xff9e1c1c)
                    : AppTheme.bgGradientEnd,
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
                backgroundColor: AppTheme.primaryGreen,
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Update Profile",
                style: TextStyle(
                  color: AppTheme.bgGradientEnd,
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
      color: AppTheme.bgGradientEnd,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFD1C4A9).withOpacity(0.5)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
      ],
    );
  }
}
