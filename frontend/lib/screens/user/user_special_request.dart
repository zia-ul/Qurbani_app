// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:intl/intl.dart';

// class MySpecialRequestsPage extends StatelessWidget {
//   const MySpecialRequestsPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final String userId = FirebaseAuth.instance.currentUser!.uid;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("My Special Requests"),
//         backgroundColor: Color(0xff537D4F),
//       ),

//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('requests')
//             .where('userId', isEqualTo: userId)
//             .orderBy('createdAt', descending: true)
//             .snapshots(),

//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text("No special requests created yet."),
//             );
//           }

//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: snapshot.data!.docs.length,
//             itemBuilder: (context, index) {
//               final doc = snapshot.data!.docs[index];
//               final data = doc.data() as Map<String, dynamic>;

//               final status = data['status'] ?? 'Pending';
//               final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
//               final repliedAt = (data['repliedAt'] as Timestamp?)?.toDate();

//               return Card(
//                 elevation: 3,
//                 margin: const EdgeInsets.only(bottom: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(14),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // 📌 Title + Status badge
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               data['title'] ?? "Request",
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: _statusColor(status),
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Text(
//                               status,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 11,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 10),

//                       // 📝 Description
//                       Text(
//                         data['description'] ?? "No description provided",
//                         style: const TextStyle(fontSize: 15),
//                       ),

//                       const SizedBox(height: 10),

//                       // 📅 Created date
//                       if (createdAt != null)
//                         Text(
//                           "Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)}",
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color: Color(0xff537D4F),
//                           ),
//                         ),

//                       // 📩 Reply message if exists
//                       if (data['replyMessage'] != null) ...[
//                         const Divider(height: 20),
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.green.shade50,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Admin Response:",
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                               const SizedBox(height: 6),
//                               Text(
//                                 data['replyMessage'],
//                                 style: const TextStyle(fontSize: 14),
//                               ),
//                               if (repliedAt != null)
//                                 Text(
//                                   "Replied: ${DateFormat('dd MMM yyyy, hh:mm a').format(repliedAt)}",
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     color: Color(0xff537D4F),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   // 🎨 Status Badge Colors
//   Color _statusColor(String status) {
//     switch (status) {
//       case 'Pending':
//         return Colors.orange;
//       case 'Replied':
//         return Colors.blue;
//       case 'Closed':
//         return Colors.green;
//       default:
//         return Color(0xff537D4F);
//     }
//   }
// }
