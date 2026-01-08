// //import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:qurbani/screens/admin/admin_home_page.dart';

// class AdminVerificationPage extends StatefulWidget {
//   const AdminVerificationPage({super.key});

//   @override
//   State<AdminVerificationPage> createState() => _AdminVerificationPageState();
// }

// class _AdminVerificationPageState extends State<AdminVerificationPage> {
//   final _formKey = GlobalKey<FormState>();

//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController governmentIdController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();

//   bool isLoading = false;
//   List<XFile> _images = [];

//   // Firestore listener subscription
//   Stream<DocumentSnapshot>? _verificationStream;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserInfo();
//     _startVerificationListener();
//   }

//   /// Load current user info
//   Future<void> _loadUserInfo() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       emailController.text = user.email ?? '';
//       final doc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .get();
//       if (doc.exists) {
//         final data = doc.data()!;
//         nameController.text = data['name'] ?? '';
//         addressController.text = data['address'] ?? '';
//       }
//     }
//   }

//   /// Listen to adminVerifications document
//   void _startVerificationListener() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     _verificationStream = FirebaseFirestore.instance
//         .collection('adminVerifications')
//         .doc(user.uid)
//         .snapshots();

//     _verificationStream!.listen((doc) async {
//       if (!doc.exists) return;
//       final status = doc['status'] ?? 'pending';

//       if (status == 'verified') {
//         // Update role in users collection
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .update({'role': 'admin'});

//         if (!mounted) return;

//         // Navigate to Admin Home Page
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) =>
//                 AdminHomePage(adminId: user.uid, name: nameController.text),
//           ),
//         );
//       }
//     });
//   }

//   /// Pick multiple images
//   Future<void> _pickImages() async {
//     final picker = ImagePicker();
//     final images = await picker.pickMultiImage();
//     setState(() => _images = images);
//   }

//   /// Upload images to Cloudinary
//   Future<List<String>> uploadImagesToCloudinary() async {
//     const cloudName = 'dfezveorl';
//     const uploadPreset = 'qurbani';
//     List<String> uploadedUrls = [];

//     for (final image in _images) {
//       final uri = Uri.parse(
//         'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
//       );
//       final request = http.MultipartRequest('POST', uri)
//         ..fields['upload_preset'] = uploadPreset
//         ..files.add(await http.MultipartFile.fromPath('file', image.path));

//       final response = await request.send();
//       if (response.statusCode == 200) {
//         final resStr = await response.stream.bytesToString();
//         final resJson = jsonDecode(resStr);
//         uploadedUrls.add(resJson['secure_url']);
//       } else {
//         throw Exception("Failed to upload ${image.name}");
//       }
//     }

//     return uploadedUrls;
//   }

//   /// Submit verification
//   Future<void> _submitVerification() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_images.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please upload at least one document")),
//       );
//       return;
//     }

//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     setState(() => isLoading = true);

//     try {
//       final documentUrls = await uploadImagesToCloudinary();

//       await FirebaseFirestore.instance
//           .collection('adminVerifications')
//           .doc(user.uid)
//           .set({
//             'adminId': user.uid,
//             'name': nameController.text.trim(),
//             'email': emailController.text.trim(),
//             'phone': phoneController.text.trim(),
//             'governmentId': governmentIdController.text.trim(),
//             'address': addressController.text.trim(),
//             'documentUrls': documentUrls,
//             'status': 'pending',
//             'submittedAt': FieldValue.serverTimestamp(),
//           });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Verification submitted successfully")),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: $e")));
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   InputDecoration _inputDecoration(String label, {String? hint}) {
//     return InputDecoration(
//       labelText: label,
//       hintText: hint,
//       filled: true,
//       fillColor: Colors.white,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//     );
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     governmentIdController.dispose();
//     addressController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return const SizedBox.shrink();

//     return StreamBuilder<DocumentSnapshot>(
//       stream: _verificationStream,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }

//         final doc = snapshot.data;
//         final status = doc != null && doc.exists
//             ? doc['status'] ?? 'pending'
//             : null;

//         // Pending submission
//         if (status == 'pending') {
//           return Scaffold(
//             appBar: AppBar(
//               title: const Text("Admin Verification"),
//               backgroundColor: Color(0xff537D4F),
//             ),
//             body: Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(24.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: const [
//                     Icon(
//                       Icons.check_circle,
//                       size: 80,
//                       color: Color(0xff537D4F),
//                     ),
//                     SizedBox(height: 20),
//                     Text(
//                       "Thanks for submitting!",
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       "We are still verifying your details. Kindly wait for approval.",
//                       style: TextStyle(fontSize: 16, color: Colors.black54),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }

//         // If no submission yet, show form
//         return Scaffold(
//           appBar: AppBar(
//             title: const Text("Register as Admin"),
//             backgroundColor: Color(0xff537D4F),
//           ),
//           body: SingleChildScrollView(
//             padding: const EdgeInsets.all(24),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   const Text(
//                     "Admin Verification",
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 12),
//                   const Text(
//                     "Provide your details for identity verification with government-approved documents. All information will be securely stored.",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(fontSize: 14, color: Colors.black54),
//                   ),
//                   const SizedBox(height: 24),

//                   TextFormField(
//                     controller: nameController,
//                     decoration: _inputDecoration("Full Name"),
//                     validator: (v) =>
//                         v == null || v.isEmpty ? "Name is required" : null,
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: emailController,
//                     readOnly: true,
//                     decoration: _inputDecoration("Email Address"),
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: phoneController,
//                     keyboardType: TextInputType.phone,
//                     decoration: _inputDecoration("Phone Number"),
//                     validator: (v) => v == null || v.isEmpty
//                         ? "Phone number is required"
//                         : null,
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: governmentIdController,
//                     decoration: _inputDecoration(
//                       "Government ID (e.g., Aadhaar, Passport)",
//                     ),
//                     validator: (v) => v == null || v.isEmpty
//                         ? "Government ID is required"
//                         : null,
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: addressController,
//                     decoration: _inputDecoration("Address"),
//                     validator: (v) =>
//                         v == null || v.isEmpty ? "Address is required" : null,
//                   ),
//                   const SizedBox(height: 16),

//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.upload_file),
//                     label: Text(
//                       _images.isEmpty
//                           ? "Upload Documents"
//                           : "${_images.length} file(s) selected",
//                     ),
//                     onPressed: _pickImages,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Color(0xff537D4F),
//                     ),
//                   ),
//                   const SizedBox(height: 24),

//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: isLoading ? null : _submitVerification,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Color(0xff537D4F),
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                       ),
//                       child: isLoading
//                           ? const CircularProgressIndicator(color: Colors.white)
//                           : const Text(
//                               "Submit Verification",
//                               style: TextStyle(fontSize: 16),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
