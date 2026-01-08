// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:qurbani/screens/admin/animal_edit.dart';

// class AnimalListingPage extends StatefulWidget {
//   const AnimalListingPage({super.key});

//   @override
//   State<AnimalListingPage> createState() => _AnimalListingPageState();
// }

// class _AnimalListingPageState extends State<AnimalListingPage> {
//   String searchQuery = "";
//   String adminCurrency = "USD";
//   bool isCurrencyLoading = true;

//   // Filter Variables
//   String? selectedType;
//   String? selectedBreed;
//   String? selectedAvailability;

//   final List<String> animalTypes = [
//     "Goat",
//     "Buffalo",
//     "Sheep",
//     "Camel",
//     "Others",
//   ];
//   final List<String> availabilityOptions = ["Yes", "No"];

//   @override
//   void initState() {
//     super.initState();
//     fetchUserCurrency();
//   }

//   Future<void> fetchUserCurrency() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final doc = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .get();
//     if (doc.exists) {
//       setState(() {
//         adminCurrency =
//             doc.data()?['currency']?.toString().replaceAll("'", "") ?? "USD";
//         isCurrencyLoading = false;
//       });
//     } else {
//       setState(() => isCurrencyLoading = false);
//     }
//   }

//   String getCurrencySymbol() {
//     switch (adminCurrency) {
//       case "INR":
//         return "₹";
//       case "USD":
//         return "\$";
//       case "AED":
//         return "د.إ ";
//       case "PKR":
//         return "Rs ";
//       default:
//         return "$adminCurrency ";
//     }
//   }

//   Future<void> _deleteAnimal(BuildContext context, String animalId) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Delete Animal"),
//         content: const Text("Are you sure you want to delete this animal?"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             child: const Text("Delete", style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       await FirebaseFirestore.instance
//           .collection('animals')
//           .doc(animalId)
//           .delete();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Animal deleted successfully")),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null)
//       return const Scaffold(body: Center(child: Text("Please Login")));

//     return Scaffold(
//       backgroundColor: const Color(0xffF4F7F4),
//       appBar: AppBar(
//         title: const Text(
//           "Animal Management",
//           style: TextStyle(
//             color: Color(0xff2D4F32),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Color(0xff2D4F32)),
//       ),
//       body: Column(
//         children: [
//           // Sticky Filter Bar
//           Container(
//             color: Colors.white,
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: DropdownButtonFormField<String>(
//                     value: selectedType,
//                     decoration: _filterInputDecoration("Type"),
//                     items: [null, ...animalTypes].map((type) {
//                       return DropdownMenuItem<String>(
//                         value: type,
//                         child: Text(
//                           type ?? "All",
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       );
//                     }).toList(),
//                     onChanged: (val) => setState(() => selectedType = val),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: TextFormField(
//                     decoration: _filterInputDecoration("Breed"),
//                     style: const TextStyle(fontSize: 12),
//                     onChanged: (val) => setState(() => selectedBreed = val),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: DropdownButtonFormField<String>(
//                     value: selectedAvailability,
//                     decoration: _filterInputDecoration("Avail."),
//                     items: [null, ...availabilityOptions].map((av) {
//                       return DropdownMenuItem<String>(
//                         value: av,
//                         child: Text(
//                           av ?? "All",
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       );
//                     }).toList(),
//                     onChanged: (val) =>
//                         setState(() => selectedAvailability = val),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Total Stats Bar
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('animals')
//                 .where('adminId', isEqualTo: user.uid)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               int total = snapshot.hasData ? snapshot.data!.docs.length : 0;
//               return Container(
//                 width: double.infinity,
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: const Color(0xffE8F2E8),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   "Total Registered Animals: $total",
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xff2D4F32),
//                   ),
//                 ),
//               );
//             },
//           ),

//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//             child: TextField(
//               onChanged: (val) =>
//                   setState(() => searchQuery = val.toLowerCase()),
//               decoration: InputDecoration(
//                 hintText: "Quick search by ID or Keywords",
//                 prefixIcon: const Icon(Icons.search),
//                 fillColor: Colors.white,
//                 filled: true,
//                 contentPadding: EdgeInsets.zero,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//             ),
//           ),

//           // Animals List
//           Expanded(
//             child: isCurrencyLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : StreamBuilder<QuerySnapshot>(
//                     stream: FirebaseFirestore.instance
//                         .collection('animals')
//                         .where('adminId', isEqualTo: user.uid)
//                         .snapshots(),
//                     builder: (context, snapshot) {
//                       if (snapshot.connectionState == ConnectionState.waiting) {
//                         return const Center(child: CircularProgressIndicator());
//                       }
//                       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                         return const Center(child: Text("No animals found."));
//                       }

//                       var docs = snapshot.data!.docs.where((doc) {
//                         final data = doc.data() as Map<String, dynamic>;

//                         // Search Filter
//                         bool matchesSearch =
//                             (data['animalType'] ?? "")
//                                 .toString()
//                                 .toLowerCase()
//                                 .contains(searchQuery) ||
//                             (data['breed'] ?? "")
//                                 .toString()
//                                 .toLowerCase()
//                                 .contains(searchQuery) ||
//                             doc.id.toLowerCase().contains(searchQuery);

//                         // Dropdown Filters
//                         bool matchesType =
//                             selectedType == null ||
//                             data['animalType'] == selectedType;
//                         bool matchesBreed =
//                             selectedBreed == null ||
//                             selectedBreed!.isEmpty ||
//                             (data['breed'] ?? "")
//                                 .toString()
//                                 .toLowerCase()
//                                 .contains(selectedBreed!.toLowerCase());
//                         bool matchesAvail =
//                             selectedAvailability == null ||
//                             (selectedAvailability == "Yes"
//                                 ? data['isAvailable'] == true
//                                 : data['isAvailable'] == false);

//                         return matchesSearch &&
//                             matchesType &&
//                             matchesBreed &&
//                             matchesAvail;
//                       }).toList();

//                       return ListView.builder(
//                         padding: const EdgeInsets.all(16),
//                         itemCount: docs.length,
//                         itemBuilder: (context, index) {
//                           var doc = docs[index];
//                           var data = doc.data() as Map<String, dynamic>;
//                           List photoUrls = data['photoUrls'] ?? [];
//                           int shares = data['shares'] ?? 1;
//                           bool isBooked = (data['isAvailable'] == false);
//                           List paymentMethods = data['paymentMethods'] ?? [];

//                           return Container(
//                             margin: const EdgeInsets.only(bottom: 16),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(12),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.05),
//                                   blurRadius: 10,
//                                 ),
//                               ],
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.all(12),
//                               child: Column(
//                                 children: [
//                                   Row(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Stack(
//                                         children: [
//                                           ClipRRect(
//                                             borderRadius: BorderRadius.circular(
//                                               8,
//                                             ),
//                                             child: photoUrls.isNotEmpty
//                                                 ? Image.network(
//                                                     photoUrls[0],
//                                                     width: 90,
//                                                     height: 90,
//                                                     fit: BoxFit.cover,
//                                                   )
//                                                 : Container(
//                                                     width: 90,
//                                                     height: 90,
//                                                     color: Colors.grey[200],
//                                                     child: const Icon(
//                                                       Icons.pets,
//                                                     ),
//                                                   ),
//                                           ),
//                                           if (isBooked)
//                                             Positioned.fill(
//                                               child: Container(
//                                                 decoration: BoxDecoration(
//                                                   color: Colors.black54,
//                                                   borderRadius:
//                                                       BorderRadius.circular(8),
//                                                 ),
//                                                 child: const Center(
//                                                   child: Text(
//                                                     "SOLD",
//                                                     style: TextStyle(
//                                                       color: Colors.white,
//                                                       fontWeight:
//                                                           FontWeight.bold,
//                                                       fontSize: 10,
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                         ],
//                                       ),
//                                       const SizedBox(width: 12),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               "${data['breed'] ?? ''} ${data['animalType'] ?? ''}",
//                                               style: const TextStyle(
//                                                 fontSize: 16,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Color(0xff2D4F32),
//                                               ),
//                                             ),
//                                             Text(
//                                               "ID: #${doc.id.substring(0, 5).toUpperCase()}",
//                                               style: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 8),
//                                             Row(
//                                               mainAxisAlignment:
//                                                   MainAxisAlignment
//                                                       .spaceBetween,
//                                               children: [
//                                                 Text(
//                                                   "${getCurrencySymbol()}${data['price'] ?? 0}",
//                                                   style: const TextStyle(
//                                                     fontSize: 14,
//                                                     fontWeight: FontWeight.bold,
//                                                     color: Colors.orange,
//                                                   ),
//                                                 ),
//                                                 _badge("Shares: $shares"),
//                                               ],
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const Divider(height: 24),
//                                   Row(
//                                     children: [
//                                       const Text(
//                                         "Payments: ",
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.bold,
//                                           color: Color(0xff537D4F),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         child: Wrap(
//                                           spacing: 8,
//                                           children: [
//                                             if (paymentMethods.contains('cod'))
//                                               _paymentTag("COD"),
//                                             if (paymentMethods.contains(
//                                               'online',
//                                             ))
//                                               _paymentTag("Online"),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 12),
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         child: OutlinedButton.icon(
//                                           onPressed: () => Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                               builder: (_) => AnimalEditPage(
//                                                 animalId: doc.id,
//                                               ),
//                                             ),
//                                           ),
//                                           icon: const Icon(
//                                             Icons.edit,
//                                             size: 16,
//                                           ),
//                                           label: const Text("Edit"),
//                                           style: OutlinedButton.styleFrom(
//                                             foregroundColor: Colors.grey[700],
//                                             side: BorderSide(
//                                               color: Colors.grey[300]!,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Expanded(
//                                         child: ElevatedButton.icon(
//                                           onPressed: () =>
//                                               _deleteAnimal(context, doc.id),
//                                           icon: const Icon(
//                                             Icons.delete,
//                                             size: 16,
//                                           ),
//                                           label: const Text("Delete"),
//                                           style: ElevatedButton.styleFrom(
//                                             backgroundColor: const Color(
//                                               0xffE57373,
//                                             ),
//                                             foregroundColor: Colors.white,
//                                             elevation: 0,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   InputDecoration _filterInputDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       labelStyle: const TextStyle(fontSize: 12),
//       border: const OutlineInputBorder(),
//       isDense: true,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//     );
//   }

//   Widget _badge(String text, {Color? color, Color? textColor}) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//       decoration: BoxDecoration(
//         color: color ?? const Color(0xffE8F2E8),
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: textColor ?? const Color(0xff537D4F),
//           fontSize: 10,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _paymentTag(String text) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.check_circle, size: 12, color: Color(0xff537D4F)),
//         const SizedBox(width: 4),
//         Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
//       ],
//     );
//   }
// }
