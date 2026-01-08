// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:qurbani/screens/user/product_details_page.dart';
// import 'package:qurbani/exchange_rates.dart';
// import 'package:qurbani/screens/user/currency_notifier.dart';

// class BookedPage extends StatefulWidget {
//   final String userId;

//   const BookedPage({super.key, required this.userId});

//   @override
//   State<BookedPage> createState() => _BookedPageState();
// }

// class _BookedPageState extends State<BookedPage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Search and Filter State
//   String searchQuery = "";
//   String selectedStatus = "All";

//   static const Color primaryGreen = Color(0xff537D4F);
//   static const Color parchmentBg = Color(0xffF2E8D5);

//   @override
//   void initState() {
//     super.initState();
//     // Listen to currency changes
//     currencyNotifier.addListener(_onCurrencyChanged);
//   }

//   @override
//   void dispose() {
//     currencyNotifier.removeListener(_onCurrencyChanged);
//     super.dispose();
//   }

//   void _onCurrencyChanged() {
//     // Rebuild the widget when currency changes
//     if (mounted) setState(() {});
//   }

//   Stream<QuerySnapshot> get ordersStream {
//     return _firestore
//         .collection('orders')
//         .where('userId', isEqualTo: widget.userId)
//         .orderBy('createdAt', descending: true)
//         .snapshots();
//   }

//   Future<Map<String, Map<String, dynamic>>> fetchAdmins(
//     List<String> adminIds,
//   ) async {
//     final Map<String, Map<String, dynamic>> adminMap = {};
//     if (adminIds.isEmpty) return adminMap;

//     final snapshots = await _firestore
//         .collection('admin_public_profiles')
//         .where(FieldPath.documentId, whereIn: adminIds)
//         .get();

//     for (var doc in snapshots.docs) {
//       adminMap[doc.id] = doc.data();
//     }
//     return adminMap;
//   }

//   // Helper method to get cart items from order data
//   List<Map<String, dynamic>> getCartItems(Map<String, dynamic> orderData) {
//     // Try both 'items' and 'cartItems' for backward compatibility
//     final items = orderData['items'] ?? orderData['cartItems'] ?? [];
//     return List<Map<String, dynamic>>.from(items);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: parchmentBg,
//       appBar: AppBar(
//         title: const Text(
//           "My Qurbani Bookings",
//           style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black87),
//       ),
//       body: Column(
//         children: [
//           const Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.0),
//             child: Text(
//               "Track your Qurbani orders and status in real time.",
//               style: TextStyle(fontSize: 12, color: Colors.black54),
//             ),
//           ),
//           _buildSearchAndFilter(),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: ordersStream,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(
//                     child: CircularProgressIndicator(color: primaryGreen),
//                   );
//                 }
//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return const Center(
//                     child: Text("You have not placed any orders yet."),
//                   );
//                 }

//                 var filteredOrders = snapshot.data!.docs.where((doc) {
//                   final data = doc.data() as Map<String, dynamic>;
//                   final orderId = (data['orderId'] ?? doc.id)
//                       .toString()
//                       .toLowerCase();
//                   final status = (data['processingStatus'] ?? 'Pending')
//                       .toString();

//                   bool matchesSearch = orderId.contains(
//                     searchQuery.toLowerCase(),
//                   );
//                   bool matchesStatus =
//                       selectedStatus == "All" || status == selectedStatus;

//                   return matchesSearch && matchesStatus;
//                 }).toList();

//                 if (filteredOrders.isEmpty)
//                   return const Center(
//                     child: Text("No matching bookings found."),
//                   );

//                 final adminIds = <String>{};
//                 for (var order in filteredOrders) {
//                   final orderData = order.data() as Map<String, dynamic>;
//                   final items = getCartItems(orderData);
//                   for (var item in items) {
//                     final aId = item['adminId'];
//                     if (aId != null && aId.isNotEmpty) adminIds.add(aId);
//                   }
//                 }

//                 return FutureBuilder<Map<String, Map<String, dynamic>>>(
//                   future: fetchAdmins(adminIds.toList()),
//                   builder: (context, adminSnapshot) {
//                     if (!adminSnapshot.hasData)
//                       return const Center(
//                         child: CircularProgressIndicator(color: primaryGreen),
//                       );
//                     final adminMap = adminSnapshot.data!;

//                     return ListView.builder(
//                       padding: const EdgeInsets.only(bottom: 20),
//                       itemCount: filteredOrders.length,
//                       itemBuilder: (_, i) =>
//                           _buildOrderCard(filteredOrders[i], adminMap),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchAndFilter() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           TextField(
//             onChanged: (val) => setState(() => searchQuery = val),
//             decoration: InputDecoration(
//               hintText: "Search Order ID...",
//               prefixIcon: const Icon(Icons.search, color: Colors.black38),
//               filled: true,
//               fillColor: Colors.white,
//               isDense: true,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 borderSide: BorderSide.none,
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 value: selectedStatus,
//                 isExpanded: true,
//                 items: ["All", "Pending", "Completed", "Processing"].map((s) {
//                   return DropdownMenuItem(value: s, child: Text("Status: $s"));
//                 }).toList(),
//                 onChanged: (val) => setState(() => selectedStatus = val!),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildOrderCard(
//     DocumentSnapshot doc,
//     Map<String, Map<String, dynamic>> adminMap,
//   ) {
//     final data = doc.data() as Map<String, dynamic>;
//     final cartItems = getCartItems(data);
//     final orderDate = (data['createdAt'] as Timestamp?)?.toDate();
//     final String pStatus = data['processingStatus'] ?? 'Pending';

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: const Color(0xffFDFBF7),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xffD1C4A9)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Flexible(
//                       child: Text(
//                         "ID: QB-${(data['orderId'] ?? doc.id).toString().substring(0, 5).toUpperCase()}",
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                     _statusBadge(pStatus),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     const Icon(
//                       Icons.check_circle,
//                       size: 14,
//                       color: Colors.green,
//                     ),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         "${data['paymentStatus']}",
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 11),
//                       ),
//                     ),
//                     const Icon(
//                       Icons.access_time,
//                       size: 14,
//                       color: Colors.brown,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       orderDate != null
//                           ? DateFormat('dd MMM').format(orderDate)
//                           : 'N/A',
//                       style: const TextStyle(fontSize: 11),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 // Delivery Status Row
//                 Row(
//                   children: [
//                     const Icon(
//                       Icons.local_shipping_outlined,
//                       size: 14,
//                       color: Colors.blue,
//                     ),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         "Delivery: ${data['deliveryStatus'] ?? 'Pending'}",
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontSize: 11,
//                           color: _getDeliveryStatusColor(
//                             data['deliveryStatus'] ?? 'Pending',
//                           ),
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     if (data['deliveryStatus'] == 'sent' &&
//                         data['deliveryCode'] != null)
//                       Row(
//                         children: [
//                           const Icon(
//                             Icons.vpn_key,
//                             size: 14,
//                             color: Colors.orange,
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             "Code: ${data['deliveryCode']}",
//                             style: const TextStyle(
//                               fontSize: 11,
//                               color: Colors.orange,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: Color(0xffD1C4A9)),
//           ...cartItems.map((item) {
//             final admin = adminMap[item['adminId']] ?? {};
//             return _buildItemRow(item, admin, data);
//           }).toList(),
//         ],
//       ),
//     );
//   }

//   Widget _statusBadge(String label) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: primaryGreen,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 10,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildItemRow(
//     Map<String, dynamic> item,
//     Map<String, dynamic> admin,
//     Map<String, dynamic> orderData,
//   ) {
//     return Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Row(
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(8),
//             child: item['photoUrl'] != null
//                 ? Image.network(
//                     item['photoUrl'],
//                     width: 50,
//                     height: 50,
//                     fit: BoxFit.cover,
//                   )
//                 : Container(
//                     width: 50,
//                     height: 50,
//                     color: Colors.grey[300],
//                     child: const Icon(Icons.pets, size: 20),
//                   ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "${item['animalType'] ?? 'Animal'} - ${item['breed'] ?? 'N/A'}",
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 13,
//                   ),
//                 ),
//                 Text(
//                   "Price: ${UserCurrency.currency} ${UserCurrency.convert(item['price'] ?? 0).toStringAsFixed(2)}",
//                   style: const TextStyle(fontSize: 11, color: Colors.black54),
//                 ),
//               ],
//             ),
//           ),
//           _actionBtn(() {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => ProductDetailsPage(
//                   orderData: orderData,
//                   productData: item,
//                   adminData: admin,
//                   userId: widget.userId,
//                 ),
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }

//   Widget _actionBtn(VoidCallback onTap) {
//     return SizedBox(
//       height: 30,
//       child: ElevatedButton(
//         onPressed: onTap,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xffE8F2E8),
//           elevation: 0,
//           padding: const EdgeInsets.symmetric(horizontal: 8),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//         ),
//         child: const Text(
//           "View >",
//           style: TextStyle(
//             fontSize: 10,
//             color: primaryGreen,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }

//   // Helper method to get delivery status color
//   Color _getDeliveryStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'pending':
//         return Colors.orange;
//       case 'sent':
//         return Colors.blue;
//       case 'delivered':
//         return Colors.green;
//       default:
//         return Colors.black54;
//     }
//   }
// }
