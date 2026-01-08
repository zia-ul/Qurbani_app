// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:qurbani/exchange_rates.dart';

// class AnimalEditPage extends StatefulWidget {
//   final String animalId;

//   const AnimalEditPage({super.key, required this.animalId});

//   @override
//   State<AnimalEditPage> createState() => _AnimalEditPageState();
// }

// class _AnimalEditPageState extends State<AnimalEditPage> {
//   final _formKey = GlobalKey<FormState>();

//   final descriptionController = TextEditingController();
//   final breedController = TextEditingController();
//   final priceController = TextEditingController();
//   final ageController = TextEditingController();
//   final sharesController = TextEditingController();
//   final animalTypeController = TextEditingController();
//   final heightController = TextEditingController();
//   final weightController = TextEditingController();
//   final deliveryFeeController = TextEditingController();

//   bool isLoading = true;
//   bool isUpdating = false;
//   List<String> existingPhotoUrls = [];
//   List<XFile> newImages = [];
//   final ImagePicker _picker = ImagePicker();
//   List<String> selectedPaymentMethods = [];
//   String? selectedAnimalType;

//   final Color primaryGreen = const Color(0xFF3D6B4E);
//   final Color lightBg = const Color(0xFFF9FBF9);

//   @override
//   void initState() {
//     super.initState();
//     _loadAnimalDetails();
//   }

//   Future<void> _loadAnimalDetails() async {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;

//     await UserCurrency.init();

//     final doc = await FirebaseFirestore.instance
//         .collection('animals')
//         .doc(widget.animalId)
//         .get();
//     if (!doc.exists) {
//       if (mounted) setState(() => isLoading = false);
//       return;
//     }

//     final data = doc.data()!;
//     double originalUsdPrice = (data['price'] ?? 0).toDouble();
//     double displayPrice = originalUsdPrice;

//     if (UserCurrency.currency != "USD") {
//       displayPrice = await CurrencyService.convert(
//         originalUsdPrice,
//         UserCurrency.currency,
//       );
//     }

//     selectedAnimalType = data['animalType'];
//     animalTypeController.text = data['animalType'] ?? '';
//     breedController.text = data['breed'] ?? '';
//     descriptionController.text = data['description'] ?? '';
//     priceController.text = displayPrice.toStringAsFixed(2);
//     ageController.text = data['age'] ?? '';
//     heightController.text = data['height']?.toString() ?? '';
//     weightController.text = data['weight']?.toString() ?? '';
//     sharesController.text = data['shares']?.toString() ?? '';
//     existingPhotoUrls = List<String>.from(data['photoUrls'] ?? []);
//     selectedPaymentMethods = List<String>.from(data['paymentMethods'] ?? []);
//     deliveryFeeController.text = data['deliveryFee']?.toString() ?? "0";

//     if (mounted) setState(() => isLoading = false);
//   }

//   Future<void> pickImages() async {
//     final List<XFile>? selectedImages = await _picker.pickMultiImage(
//       imageQuality: 80,
//     );
//     if (selectedImages != null && selectedImages.isNotEmpty) {
//       setState(() => newImages.addAll(selectedImages));
//     }
//   }

//   Future<List<String>> _uploadNewImages() async {
//     const cloudName = 'dfezveorl';
//     const uploadPreset = 'qurbani';
//     List<String> uploadedUrls = [];

//     for (final image in newImages) {
//       final uri = Uri.parse(
//         'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
//       );
//       final request = http.MultipartRequest('POST', uri)
//         ..fields['upload_preset'] = uploadPreset
//         ..files.add(await http.MultipartFile.fromPath('file', image.path));

//       final response = await request.send();
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(await response.stream.bytesToString());
//         uploadedUrls.add(decoded['secure_url']);
//       }
//     }
//     return uploadedUrls;
//   }

//   Future<void> updateAnimal() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (existingPhotoUrls.isEmpty && newImages.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("At least one image is required")),
//       );
//       return;
//     }

//     setState(() => isUpdating = true);

//     try {
//       double enteredPrice = double.tryParse(priceController.text.trim()) ?? 0;
//       double priceToSave = enteredPrice;
//       if (UserCurrency.currency != "USD") {
//         priceToSave = await CurrencyService.convert(enteredPrice, "USD");
//       }

//       List<String> newlyUploaded = await _uploadNewImages();
//       final finalPhotoList = [...existingPhotoUrls, ...newlyUploaded];

//       await FirebaseFirestore.instance
//           .collection('animals')
//           .doc(widget.animalId)
//           .update({
//             'animalType':
//                 selectedAnimalType ?? animalTypeController.text.trim(),
//             'breed': breedController.text.trim(),
//             'description': descriptionController.text.trim(),
//             'price': priceToSave,
//             'age': ageController.text.trim(),
//             'height': heightController.text.trim(),
//             'weight': weightController.text.trim(),
//             'shares': int.tryParse(sharesController.text.trim()) ?? 0,
//             'photoUrls': finalPhotoList,
//             'paymentMethods': selectedPaymentMethods,
//             'deliveryFee': double.tryParse(deliveryFeeController.text) ?? 0.0,
//             'updatedAt': FieldValue.serverTimestamp(),
//           });

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Animal updated successfully")),
//       );
//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error updating: $e")));
//     } finally {
//       if (mounted) setState(() => isUpdating = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       backgroundColor: lightBg,
//       appBar: AppBar(
//         title: Text(
//           "Edit Animal Details",
//           style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: IconThemeData(color: primaryGreen),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               _buildCardContainer([
//                 _buildLabel("Animal Type", isReq: true),
//                 DropdownButtonFormField<String>(
//                   value:
//                       [
//                         "Goat",
//                         "Buffalo",
//                         "Sheep",
//                         "Camel",
//                       ].contains(selectedAnimalType)
//                       ? selectedAnimalType
//                       : null,
//                   decoration: _inputDecoration("Select Type"),
//                   items: ["Goat", "Buffalo", "Sheep", "Camel"]
//                       .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                       .toList(),
//                   onChanged: (val) => setState(() => selectedAnimalType = val),
//                 ),
//                 const SizedBox(height: 15),
//                 TextFormField(
//                   controller: animalTypeController,
//                   decoration: _inputDecoration("Or Specify Type"),
//                 ),
//                 const SizedBox(height: 15),
//                 _buildLabel("Animal Breed", isReq: true),
//                 TextFormField(
//                   controller: breedController,
//                   decoration: _inputDecoration("e.g. Sahiwal"),
//                   validator: (v) => v!.isEmpty ? "Required" : null,
//                 ),
//                 const SizedBox(height: 15),
//                 _buildLabel("Description (Optional)", isReq: false),
//                 TextFormField(
//                   controller: descriptionController,
//                   maxLines: 3,
//                   decoration: _inputDecoration("Appearance details..."),
//                 ),
//               ]),
//               const SizedBox(height: 20),
//               _buildCardContainer([
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildLabel("Height", isReq: true),
//                           TextFormField(
//                             controller: heightController,
//                             decoration: _inputDecoration("cm / ft"),
//                             validator: (v) => v!.isEmpty ? "Required" : null,
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 15),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildLabel(
//                             "Price (${UserCurrency.currency})",
//                             isReq: true,
//                           ),
//                           TextFormField(
//                             controller: priceController,
//                             keyboardType: TextInputType.number,
//                             decoration: _inputDecoration("0.00"),
//                             validator: (v) => v!.isEmpty ? "Required" : null,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 15),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildLabel("Weight (Optional)", isReq: false),
//                           TextFormField(
//                             controller: weightController,
//                             keyboardType: TextInputType.number,
//                             decoration: _inputDecoration("kg"),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 15),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildLabel("Age (Optional)", isReq: false),
//                           TextFormField(
//                             controller: ageController,
//                             decoration: _inputDecoration("e.g. 2 yrs"),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ]),
//               const SizedBox(height: 20),
//               _buildCardContainer([
//                 _buildLabel("Shares Available", isReq: true),
//                 TextFormField(
//                   controller: sharesController,
//                   keyboardType: TextInputType.number,
//                   decoration: _inputDecoration("Total Shares"),
//                   validator: (v) => v!.isEmpty ? "Required" : null,
//                 ),
//               ]),
//               const SizedBox(height: 20),
//               _buildCardContainer([
//                 _buildLabel("Gallery (Existing & New)", isReq: true),
//                 const SizedBox(height: 10),
//                 _buildCombinedImageGallery(),
//                 const SizedBox(height: 15),
//                 ElevatedButton.icon(
//                   onPressed: pickImages,
//                   icon: const Icon(Icons.add_a_photo),
//                   label: const Text("Add More Photos"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: primaryGreen,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size(double.infinity, 45),
//                   ),
//                 ),
//               ]),
//               const SizedBox(height: 20),
//               _buildCardContainer([
//                 _buildLabel("Payment Method", isReq: true),
//                 Row(
//                   children: [
//                     _buildCheckbox("COD", 'cod'),
//                     _buildCheckbox("Online", 'online'),
//                   ],
//                 ),
//               ]),
//               const SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 height: 55,
//                 child: ElevatedButton(
//                   onPressed: isUpdating ? null : updateAnimal,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: primaryGreen,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   child: isUpdating
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : const Text(
//                           "Update Animal",
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                 ),
//               ),
//               const SizedBox(height: 40),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCardContainer(List<Widget> children) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: children,
//       ),
//     );
//   }

//   Widget _buildLabel(String text, {bool isReq = true}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8, top: 4),
//       child: RichText(
//         text: TextSpan(
//           text: text,
//           style: const TextStyle(
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//           children: isReq
//               ? [
//                   const TextSpan(
//                     text: ' *',
//                     style: TextStyle(color: Colors.red),
//                   ),
//                 ]
//               : [],
//         ),
//       ),
//     );
//   }

//   InputDecoration _inputDecoration(String hint) {
//     return InputDecoration(
//       hintText: hint,
//       filled: true,
//       fillColor: Colors.grey[50],
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: Colors.grey[300]!),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: primaryGreen),
//       ),
//     );
//   }

//   Widget _buildCheckbox(String title, String key) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Checkbox(
//           value: selectedPaymentMethods.contains(key),
//           activeColor: primaryGreen,
//           onChanged: (val) {
//             setState(() {
//               if (val!) {
//                 selectedPaymentMethods.add(key);
//               } else {
//                 selectedPaymentMethods.remove(key);
//               }
//             });
//           },
//         ),
//         Text(title, style: const TextStyle(fontSize: 13)),
//       ],
//     );
//   }

//   Widget _buildCombinedImageGallery() {
//     return SizedBox(
//       height: 100,
//       child: ListView(
//         scrollDirection: Axis.horizontal,
//         children: [
//           ...existingPhotoUrls.asMap().entries.map(
//             (entry) => _imageTile(
//               Image.network(
//                 entry.value,
//                 width: 80,
//                 height: 80,
//                 fit: BoxFit.cover,
//               ),
//               () => setState(() => existingPhotoUrls.removeAt(entry.key)),
//             ),
//           ),
//           ...newImages.asMap().entries.map(
//             (entry) => _imageTile(
//               Image.file(
//                 File(entry.value.path),
//                 width: 80,
//                 height: 80,
//                 fit: BoxFit.cover,
//               ),
//               () => setState(() => newImages.removeAt(entry.key)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _imageTile(Widget img, VoidCallback onDelete) {
//     return Stack(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(4.0),
//           child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
//         ),
//         Positioned(
//           right: 0,
//           top: 0,
//           child: GestureDetector(
//             onTap: onDelete,
//             child: const CircleAvatar(
//               radius: 10,
//               backgroundColor: Colors.red,
//               child: Icon(Icons.close, size: 12, color: Colors.white),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
