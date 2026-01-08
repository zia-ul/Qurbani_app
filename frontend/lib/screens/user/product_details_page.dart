// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:qurbani/screens/user/receipt_generator.dart';
// import 'package:qurbani/screens/user/special_request.dart';
// import 'package:qurbani/screens/user/rate_order.dart';
// import 'package:qurbani/exchange_rates.dart';
// import 'package:qurbani/screens/user/currency_notifier.dart';

// class ProductDetailsPage extends StatefulWidget {
//   final Map<String, dynamic> orderData;
//   final Map<String, dynamic> productData;
//   final Map<String, dynamic>? adminData;
//   final String userId;

//   const ProductDetailsPage({
//     super.key,
//     required this.orderData,
//     required this.productData,
//     this.adminData,
//     required this.userId,
//   });

//   @override
//   State<ProductDetailsPage> createState() => _ProductDetailsPageState();
// }

// class _ProductDetailsPageState extends State<ProductDetailsPage> {
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

//   // Theme Colors from reference
//   final Color primaryGreen = const Color(0xff3D6B4E);
//   final Color bgParchment = const Color(0xffF2E8D5);

//   Widget _buildSectionCard({
//     required String title,
//     required Widget child,
//     required IconData icon,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.9),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: const Color(0xFFD1C4A9), width: 1),
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
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: const Color(0xFFE8F1F9).withOpacity(0.5),
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(15),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Icon(icon, size: 18, color: primaryGreen),
//                 const SizedBox(width: 8),
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: primaryGreen,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Padding(padding: const EdgeInsets.all(16.0), child: child),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(
//     IconData icon,
//     String label,
//     String value, {
//     bool isCopyable = false,
//     BuildContext? context,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         children: [
//           Icon(icon, size: 16, color: Colors.grey[600]),
//           const SizedBox(width: 8),
//           Text(
//             "$label: ",
//             style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(color: Colors.grey[800], fontSize: 13),
//             ),
//           ),
//           if (isCopyable && context != null)
//             IconButton(
//               icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
//               onPressed: () {
//                 Clipboard.setData(ClipboardData(text: value));
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(const SnackBar(content: Text("ID Copied!")));
//               },
//               constraints: const BoxConstraints(),
//               padding: EdgeInsets.zero,
//             ),
//         ],
//       ),
//     );
//   }

//   Future<void> _cancelOrder(BuildContext context) async {
//     // Logic to handle cancellation confirmation
//     bool? confirm = await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Cancel Order"),
//         content: const Text(
//           "Are you sure you want to cancel? This action cannot be undone.",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("No"),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             child: const Text(
//               "Yes, Cancel",
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         ],
//       ),
//     );

//     if (confirm != true) return;

//     final orderId = widget.orderData['orderId'];
//     try {
//       WriteBatch batch = FirebaseFirestore.instance.batch();
//       DocumentReference orderRef = FirebaseFirestore.instance
//           .collection('orders')
//           .doc(orderId);
//       DocumentReference adminRef = FirebaseFirestore.instance
//           .collection('admin_orders')
//           .doc(orderId);

//       var updateData = {
//         'paymentStatus': 'Cancelled',
//         'processingStatus': 'Cancelled',
//         'deliveryStatus': 'Cancelled',
//         'cancelledAt': FieldValue.serverTimestamp(),
//       };

//       batch.update(orderRef, updateData);
//       batch.update(adminRef, updateData);
//       await batch.commit();

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Order Cancelled Successsfully")),
//       );
//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: $e")));
//     }
//   }

//   Widget _actionButton(
//     String label,
//     IconData icon,
//     Color color,
//     VoidCallback onPressed,
//   ) {
//     return ElevatedButton.icon(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: Colors.white,
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       onPressed: onPressed,
//       icon: Icon(icon),
//       label: Text(label),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final deliveryStatus = (widget.orderData['deliveryStatus'] ?? 'Pending')
//         .toString();
//     final orderDate = (widget.orderData['createdAt'] as Timestamp?)?.toDate();
//     final bool isDelivered = deliveryStatus.toLowerCase() == 'delivered';
//     final bool isCancelled = deliveryStatus.toLowerCase() == 'cancelled';

//     bool canCancel = false;
//     if (orderDate != null) {
//       canCancel =
//           DateTime.now().difference(orderDate).inHours < 24 &&
//           !isDelivered &&
//           !isCancelled;
//     }

//     return Scaffold(
//       backgroundColor: bgParchment,
//       appBar: AppBar(
//         title: const Text(
//           "Order Details",
//           style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.black87),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // 1. Product Info Card
//             _buildSectionCard(
//               title: "Product Info",
//               icon: Icons.pets,
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: Image.network(
//                       widget.productData['imageUrl'] ??
//                           'https://via.placeholder.com/150',
//                       width: 100,
//                       height: 100,
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           widget.productData['title'] ?? 'Animal',
//                           style: const TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         _buildInfoRow(
//                           Icons.pie_chart,
//                           "Shares",
//                           "${widget.productData['shares'] ?? 0}",
//                         ),
//                         _buildInfoRow(
//                           Icons.payments,
//                           "Price",
//                           "${UserCurrency.currency} ${UserCurrency.convert(widget.productData['price'] ?? 0).toStringAsFixed(2)}",
//                         ),
//                         if (widget.productData['barcode'] != null)
//                           _buildInfoRow(
//                             Icons.qr_code,
//                             "Barcode",
//                             "${widget.productData['barcode']}",
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // 2. Admin Details Card
//             _buildSectionCard(
//               title: "Admin Details",
//               icon: Icons.account_circle,
//               child: Row(
//                 children: [
//                   // const CircleAvatar(
//                   // radius: 25,
//                   // backgroundImage: NetworkImage(
//                   // 'https://via.placeholder.com/150',
//                   // ),
//                   // ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           widget.adminData?['name'] ?? 'Admin Hajra',
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         Text(
//                           widget.adminData?['phone'] ?? '+91 9876543210',
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                         Text(
//                           widget.adminData?['address'] ??
//                               'Hyderabad, Telangana',
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   // ElevatedButton.icon(
//                   // onPressed: () async {
//                   //   final String phoneNumber =
//                   //       this.adminData?['phone'] ?? '+910000000000';
//                   //   final Uri launchUri = Uri(
//                   //     scheme: 'tel',
//                   //     path: phoneNumber,
//                   //   );

//                   //   if (await canLaunchUrl(launchUri)) {
//                   //     await launchUrl(launchUri);
//                   //   } else {
//                   // Handle the error, e.g., show a snackbar
//                   // ScaffoldMessenger.of(context).showSnackBar(
//                   //   const SnackBar(content: Text("Could not launch dialer")),
//                   // );
//                   // }
//                   //   },
//                   //   icon: const Icon(Icons.call, size: 16),
//                   //   label: const Text("Call Admin"),
//                   //   style: ElevatedButton.styleFrom(
//                   //     backgroundColor: const Color(0xff537D4F), // primaryGreen
//                   //     foregroundColor: Colors.white,
//                   //     padding: const EdgeInsets.symmetric(
//                   //       horizontal: 12,
//                   //       vertical: 8,
//                   //     ),
//                   //     shape: RoundedRectangleBorder(
//                   //       borderRadius: BorderRadius.circular(8),
//                   //     ),
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),

//             // 3. Order Info Card
//             _buildSectionCard(
//               title: "Order Info",
//               icon: Icons.assignment,
//               child: Column(
//                 children: [
//                   _buildInfoRow(
//                     Icons.fingerprint,
//                     "Order ID",
//                     widget.orderData['orderId'],
//                     isCopyable: true,
//                     context: context,
//                   ),
//                   _buildInfoRow(
//                     Icons.check_circle,
//                     "Payment Status",
//                     widget.orderData['paymentStatus'] ?? 'Paid',
//                   ),
//                   _buildInfoRow(
//                     Icons.timer,
//                     "Processing Status",
//                     widget.orderData['processingStatus'] ?? 'Pending',
//                   ),
//                   _buildInfoRow(
//                     Icons.local_shipping,
//                     "Delivery Status",
//                     deliveryStatus,
//                   ),
//                   if (orderDate != null)
//                     _buildInfoRow(
//                       Icons.calendar_today,
//                       "Ordered on",
//                       DateFormat('dd MMMM yyyy').format(orderDate),
//                     ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 20),

//             // Functional Buttons Row
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildActionBtn(
//                     label: "Special Request",
//                     icon: Icons.edit_note,
//                     color: primaryGreen,
//                     onPressed: (isCancelled || isDelivered)
//                         ? null
//                         : () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => SpecialRequestPage(
//                                 orderData: widget.orderData,
//                               ),
//                             ),
//                           ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: _buildActionBtn(
//                     label: "Download Receipt",
//                     icon: Icons.download,
//                     color: Colors.blue[700]!,
//                     onPressed: () async {
//                       final file = await generateReceiptPDF(widget.orderData);
//                       await OpenFilex.open(file.path);
//                     },
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),

//             // Rate and Cancel Buttons
//             if (isDelivered)
//               _buildActionBtn(
//                 label: "Rate Admin & Delivery",
//                 icon: Icons.star,
//                 color: Colors.orange[800]!,
//                 onPressed: () => Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => RateOrderPage(
//                       orderId: widget.orderData['orderId'],
//                       userId: widget.userId,
//                     ),
//                   ),
//                 ),
//               ),

//             if (canCancel)
//               _buildActionBtn(
//                 label: "Cancel Order",
//                 icon: Icons.cancel,
//                 color: Colors.red,
//                 onPressed: () => _cancelOrder(context),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildActionBtn({
//     required String label,
//     required IconData icon,
//     required Color color,
//     required VoidCallback? onPressed,
//   }) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         onPressed: onPressed,
//         icon: Icon(icon, size: 18),
//         label: Text(label),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: Colors.grey[400],
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       ),
//     );
//   }
// }
