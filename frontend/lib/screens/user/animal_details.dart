// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:qurbani/screens/user/cart_service.dart';
// import 'package:qurbani/exchange_rates.dart';
// import 'package:qurbani/screens/user/currency_notifier.dart';
// import 'admin_profile.dart';

// class AnimalDetailPage extends StatefulWidget {
//   final String animalId;

//   const AnimalDetailPage({super.key, required this.animalId});

//   @override
//   State<AnimalDetailPage> createState() => _AnimalDetailPageState();
// }

// class _AnimalDetailPageState extends State<AnimalDetailPage> {
//   bool isRateLoading = true;
//   int selectedShares = 1;

//   @override
//   void initState() {
//     super.initState();
//     // _initCurrency();
//   }

//   // Future<void> _initCurrency() async {
//   //   setState(() => isRateLoading = true);
//   //   await UserCurrency.init();
//   //   setState(() => isRateLoading = false);
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(
//         0xffF4F7F4,
//       ), // Light green background from reference
//       appBar: AppBar(
//         title: const Text(
//           "Animal Details",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: const Color(0xff537D4F),
//         elevation: 0,
//         centerTitle: true,
//       ),
//       body: StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('animals')
//             .doc(widget.animalId)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData)
//             return const Center(child: CircularProgressIndicator());
//           if (!snapshot.data!.exists)
//             return const Center(child: Text("Animal not found"));

//           final data = snapshot.data!.data() as Map<String, dynamic>;
//           final num sharesNum = data['shares'] ?? 0;
//           final int maxShares = sharesNum.toInt();
//           final bool isAvailable =
//               (data['isAvailable'] ?? false) && maxShares > 0;
//           final double priceUSD = (data['price'] ?? 0).toDouble();
//           // final double priceConverted = UserCurrency.convert(priceUSD);
//           final List<String> imageUrls = List<String>.from(
//             data['photoUrls'] ?? [],
//           );
//           final String adminId = data['adminId'] ?? '';
//           final double deliveryFee = (data['deliveryFee'] ?? 0).toDouble();

//           return Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // --- IMAGE SECTION ---
//                       Stack(
//                         children: [
//                           imageUrls.isNotEmpty
//                               ? SizedBox(
//                                   height: 280,
//                                   width: double.infinity,
//                                   child: PageView.builder(
//                                     itemCount: imageUrls.length,
//                                     itemBuilder: (context, index) =>
//                                         Image.network(
//                                           imageUrls[index],
//                                           fit: BoxFit.cover,
//                                         ),
//                                   ),
//                                 )
//                               : _imageFallback(),
//                           Positioned(
//                             bottom: 0,
//                             left: 0,
//                             right: 0,
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 12,
//                                 horizontal: 16,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   begin: Alignment.topCenter,
//                                   end: Alignment.bottomCenter,
//                                   colors: [
//                                     Colors.transparent,
//                                     Colors.black.withOpacity(0.7),
//                                   ],
//                                 ),
//                               ),
//                               child: Text(
//                                 "${data['breed'] ?? 'Pure Breed'} ${data['animalType'] ?? ''}",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 24,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),

//                       Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Column(
//                           children: [
//                             // --- ANIMAL DETAILS CARD ---
//                             _buildInfoCard(
//                               title: "Animal Details",
//                               icon: Icons.pets,
//                               children: [
//                                 _detailRow("Type", data['animalType'] ?? 'N/A'),
//                                 _detailRow("Breed", data['breed'] ?? 'N/A'),
//                                 _detailRow(
//                                   "Age",
//                                   "${data['age'] ?? 'N/A'} Months",
//                                 ),
//                                 _detailRow(
//                                   "Height",
//                                   "${data['height'] ?? '0'} cm",
//                                 ),
//                                 if (data['description'] != null &&
//                                     data['description']
//                                         .toString()
//                                         .trim()
//                                         .isNotEmpty)
//                                   _detailRow(
//                                     "Description",
//                                     data['description'],
//                                   ),
//                               ],
//                             ),
//                             const SizedBox(height: 16),

//                             // --- ADMIN DETAILS CARD ---
//                             _buildAdminCard(adminId),
//                             const SizedBox(height: 16),

//                             // --- DELIVERY & PRICE CARD ---
//                             _buildInfoCard(
//                               title: "Price & Delivery",
//                               icon: Icons.delivery_dining,
//                               children: [
//                                 _detailRow(
//                                   "Price per Share", "${priceUSD} ${priceUSD}",
//                                   // "${UserCurrency.currency} ${priceConverted.toStringAsFixed(2)}",
//                                 ),
//                                 _detailRow("Available Shares", "$maxShares"),
//                                 _detailRow(
//                                   "Delivery Charges",
//                                   deliveryFee == 0
//                                       ? "Free":"",
//                                       // : "${UserCurrency.currency} $deliveryFee",
//                                 ),
//                                 const Divider(),
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     const Text(
//                                       "Select Shares:",
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     Row(
//                                       children: [
//                                         _shareBtn(Icons.remove, () {
//                                           if (selectedShares > 1)
//                                             setState(() => selectedShares--);
//                                         }),
//                                         Padding(
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                           ),
//                                           child: Text(
//                                             "$selectedShares",
//                                             style: const TextStyle(
//                                               fontSize: 18,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                         _shareBtn(Icons.add, () {
//                                           if (selectedShares < maxShares)
//                                             setState(() => selectedShares++);
//                                         }),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               // --- BOTTOM ACTION BAR ---
//               _buildBottomBar(
//                 isAvailable,
//                 // priceConverted,
//                 priceUSD,
//                 data,
//                 imageUrls,
//                 adminId,
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildInfoCard({
//     required String title,
//     required IconData icon,
//     required List<Widget> children,
//   }) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
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
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: const Color(0xff537D4F), size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xff537D4F),
//                 ),
//               ),
//             ],
//           ),
//           const Divider(height: 24),
//           ...children,
//         ],
//       ),
//     );
//   }

//   Widget _detailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 color: Color(0xff537D4F),
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAdminCard(String adminId) {
//     return StreamBuilder<DocumentSnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(adminId)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return const SizedBox();
//         final userData = snapshot.data!.data() as Map<String, dynamic>?;
//         if (userData == null) return const SizedBox();

//         // Wrap the card in InkWell to make it clickable
//         return InkWell(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => AdminProfilePage(adminId: adminId),
//               ),
//             );
//           },
//           child: _buildInfoCard(
//             title: "Seller Details",
//             icon: Icons.person,
//             children: [
//               Row(
//                 children: [
//                   CircleAvatar(
//                     radius: 25,
//                     backgroundImage: userData['photoUrl'] != null
//                         ? NetworkImage(userData['photoUrl'])
//                         : null,
//                     child: userData['photoUrl'] == null
//                         ? const Icon(Icons.person)
//                         : null,
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           userData['name'] ?? 'Admin',
//                           style: const TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                         Row(
//                           children: [
//                             const Icon(
//                               Icons.star,
//                               color: Color(0xff537D4F),
//                               size: 16,
//                             ),
//                             Text(
//                               " ${(userData['averageRating'] ?? 0).toDouble().toStringAsFixed(1)} (Verified Seller)",
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Color(0xff537D4F),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Added a small arrow to indicate it's clickable
//                   const Icon(
//                     Icons.arrow_forward_ios,
//                     size: 16,
//                     color: Color(0xff537D4F),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _adminActionBtn(String label, IconData icon, VoidCallback onTap) {
//     return OutlinedButton.icon(
//       onPressed: onTap,
//       icon: Icon(icon, size: 16),
//       label: Text(label, style: const TextStyle(fontSize: 12)),
//       style: OutlinedButton.styleFrom(
//         foregroundColor: const Color(0xff537D4F),
//         side: const BorderSide(color: Color(0xff537D4F)),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   Widget _shareBtn(IconData icon, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Icon(icon, size: 20),
//       ),
//     );
//   }

//   Widget _buildBottomBar(
//     bool isAvailable,
//     // double priceConverted,
//     double priceUSD,
//     Map data,
//     List imageUrls,
//     String adminId,
//   ) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   "Total Payable:",
//                   style: TextStyle(color: Color(0xff537D4F), fontSize: 12),
//                 ),
//                 // Text(
//                   // "${UserCurrency.currency} ${(priceConverted * selectedShares).toStringAsFixed(2)}",
//                   // style: const TextStyle(
//                   //   fontSize: 20,
//                   //   fontWeight: FontWeight.bold,
//                   //   color: Color(0xff537D4F),
//                   // ),
//                 // ),
//               ],
//             ),
//           ),
//           SizedBox(
//             width: 160,
//             height: 50,
//             child: ElevatedButton(
//               onPressed: isAvailable
//                   ? () async {
//                       try {
//                         await CartService.addAnimalToCart(
//                           animalId: widget.animalId,
//                           animalData: {
//                             'animalType': data['animalType'],
//                             'breed': data['breed'],
//                             'price': priceUSD,
//                             'shares': selectedShares,
//                             'photoUrl': imageUrls.isNotEmpty
//                                 ? imageUrls.first
//                                 : null,
//                             'adminId': adminId,
//                           },
//                         );
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(content: Text("Added to cart")),
//                         );
//                       } catch (e) {
//                         ScaffoldMessenger.of(
//                           context,
//                         ).showSnackBar(SnackBar(content: Text(e.toString())));
//                       }
//                     }
//                   : null,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xff537D4F),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: Text(
//                 isAvailable ? "Proceed" : "Sold Out",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _imageFallback() {
//     return Container(
//       height: 280,
//       width: double.infinity,
//       color: Colors.grey.shade300,
//       child: const Icon(
//         Icons.image_not_supported,
//         size: 80,
//         color: Color(0xff537D4F),
//       ),
//     );
//   }
// }
