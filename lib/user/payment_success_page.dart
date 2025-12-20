import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/special_request.dart';
import 'package:qurbani1/user/user_home_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class PaymentSuccessPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const PaymentSuccessPage({super.key, required this.orderData});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _processed = false;
  bool _ratingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _finalizeOrderOnce();
    _checkIfAlreadyRated();
  }

  /// FINALIZE ORDER
  Future<void> _finalizeOrderOnce() async {
    if (_processed) return; // prevent double-finalize
    _processed = true;

    final data = Map<String, dynamic>.from(widget.orderData);
    final orderId = data['orderId'] as String;
    final userId = data['userId'] as String;
    final paymentMethod = data['paymentMethod'] as String;

    final List<Map<String, dynamic>> cartItems =
        List<Map<String, dynamic>>.from(data['cartItems'] ?? []);

    final List<Map<String, dynamic>> shareholders =
        List<Map<String, dynamic>>.from(data['shareholders'] ?? []);

    try {
      await _firestore.runTransaction((transaction) async {
        // ─────────────────────────────────────
        // 1️⃣ READ ALL ANIMAL DOCS FIRST (no writes yet)
        // ─────────────────────────────────────
        final Map<String, DocumentSnapshot> animalSnapshots = {};
        final Map<String, int> sharesPerAnimal = {};

        for (var item in cartItems) {
          final animalId = item['animalId'] as String;
          final shares = (item['shares'] ?? 1) as int;
          sharesPerAnimal[animalId] = (sharesPerAnimal[animalId] ?? 0) + shares;
        }

        for (var animalId in sharesPerAnimal.keys) {
          final ref = _firestore.collection('animals').doc(animalId);
          final snap = await transaction.get(ref);
          if (!snap.exists) throw Exception("Animal $animalId not found");
          animalSnapshots[animalId] = snap;
        }

        // ─────────────────────────────────────
        // 2️⃣ VALIDATE STOCK
        // ─────────────────────────────────────
        for (var entry in sharesPerAnimal.entries) {
          final animal = animalSnapshots[entry.key]!;
          final available = (animal['shares'] ?? 0).toInt();
          if (available < entry.value) {
            throw Exception("Not enough shares for ${animal['title']}");
          }
        }

        // ─────────────────────────────────────
        // 3️⃣ WRITE MAIN ORDER
        // ─────────────────────────────────────
        final orderRef = _firestore.collection('orders').doc(orderId);
        transaction.set(orderRef, {
          ...data,
          'paymentStatus': paymentMethod == 'online' ? 'paid' : 'pending',
          'processingStatus': 'Pending',
          'deliveryStatus': 'Pending',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ─────────────────────────────────────
        // 4️⃣ DEDUCT ANIMAL SHARES
        // ─────────────────────────────────────
        for (var entry in sharesPerAnimal.entries) {
          final animalId = entry.key;
          final purchased = entry.value;
          final snap = animalSnapshots[animalId]!;
          final remaining = (snap['shares'] ?? 0) - purchased;

          transaction.update(snap.reference, {
            'shares': remaining,
            'isAvailable': remaining > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // ─────────────────────────────────────
        // 5️⃣ BUILD ADMIN ORDERS
        // ─────────────────────────────────────
        final Map<String, List<Map<String, dynamic>>> adminBuckets = {};

        for (var s in shareholders) {
          final cartItem = cartItems.firstWhere(
            (c) => c['animalId'] == s['animalId'],
            orElse: () => {},
          );
          final adminId = cartItem['adminId'];
          if (adminId == null) continue;

          s['adminId'] = adminId;
          adminBuckets.putIfAbsent(adminId, () => []);
          adminBuckets[adminId]!.add(s);
        }

        for (var entry in adminBuckets.entries) {
          final adminId = entry.key;
          final adminOrderId = "$orderId-$adminId";
          final adminShareholders = entry.value;

          Map<String, Map<String, dynamic>> animalMap = {};

          for (var s in adminShareholders) {
            final animalId = s['animalId'];
            final cartItem = cartItems.firstWhere(
              (c) => c['animalId'] == animalId,
            );

            animalMap.putIfAbsent(animalId, () {
              return {
                'animalId': animalId,
                'title': cartItem['title'],
                'adminId': adminId,
                'price': cartItem['price'],
                'sharesPurchased': 0,
              };
            });

            animalMap[animalId]!['sharesPurchased'] =
                (animalMap[animalId]!['sharesPurchased'] ?? 0) + 1;
          }

          final adminOrderRef = _firestore
              .collection('admin_orders')
              .doc(adminOrderId);

          transaction.set(adminOrderRef, {
            'adminId': adminId,
            'orderId': orderId,
            'userId': userId,
            'delivery_person_id': data['deliveryPersonId'],
            'shareholders': adminShareholders,
            'animalItems': animalMap.values.toList(),
            'contact_details': data['contactDetails'],
            'delivery_address': data['deliveryAddress'],
            'qurbani_day': data['qurbaniDay'],
            'payment_status': paymentMethod == 'online'
                ? 'Done'
                : 'Cash Pending',
            'processing_status': 'Pending',
            'delivery_status': 'Pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // ─────────────────────────────────────
        // 6️⃣ EMPTY USER CART
        // ─────────────────────────────────────
        final cartSnap = await _firestore
            .collection('carts')
            .doc(userId)
            .collection('items')
            .get();

        for (var doc in cartSnap.docs) {
          transaction.delete(doc.reference);
        }
      });

      debugPrint("✅ ORDER FINALIZED: cart cleared & shares deducted");
    } catch (e) {
      debugPrint("❌ FINALIZE ORDER FAILED: $e");
      rethrow; // bubble up to UI if needed
    }
  }

  /// CHECK IF RATING ALREADY EXISTS
  Future<void> _checkIfAlreadyRated() async {
    try {
      final doc = await _firestore
          .collection('ratings')
          .doc(widget.orderData['orderId'])
          .get();
      if (doc.exists && doc.data()?['userId'] == widget.orderData['userId']) {
        setState(() => _ratingSubmitted = true);
      }
    } catch (e) {
      debugPrint("Cannot read rating: $e");
      setState(() => _ratingSubmitted = false);
    }
  }

  /// GENERATE PDF RECEIPT
  Future<File> generateReceiptPDF(Map<String, dynamic> orderData) async {
    final pdf = pw.Document();
    final shareholders = List<Map<String, dynamic>>.from(
      orderData['shareholders'] ?? [],
    );

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Receipt', style: pw.TextStyle(fontSize: 22)),
            pw.Text('Order ID: ${orderData['orderId']}'),
            pw.Text('Amount: ₹${orderData['totalAmount']}'),
            pw.SizedBox(height: 10),
            ...shareholders.map(
              (s) =>
                  pw.Text('${s['animalType']} - ${s['name']} (${s['gender']})'),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${orderData['orderId']}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderData['orderId'];
    final amount = widget.orderData['totalAmount'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Colors.green),
            Text('Order ID: $orderId'),
            Text('Amount: ₹$amount'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Download Receipt'),
              onPressed: () async {
                final file = await generateReceiptPDF(widget.orderData);
                await OpenFilex.open(file.path);
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text('Back to Home'),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(
                      id: widget.orderData['userId'],
                      name: widget.orderData['userName'] ?? 'User',
                    ),
                  ),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
