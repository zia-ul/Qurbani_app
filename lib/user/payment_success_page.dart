import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/receipt_generator.dart';
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

  double productRating = 0;
  double deliveryRating = 0;

  final productReviewController = TextEditingController();
  final deliveryReviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _finalizeOrderOnce();
    _checkIfAlreadyRated();
  }

  @override
  void dispose() {
    productReviewController.dispose();
    deliveryReviewController.dispose();
    super.dispose();
  }

  /// FINALIZE ORDER
  Future<void> _finalizeOrderOnce() async {
    if (_processed) return;
    _processed = true;

    final data = Map<String, dynamic>.from(widget.orderData);
    final orderId = data['orderId'];
    final userId = data['userId'];
    final paymentMethod = data['paymentMethod'];
    final List<Map<String, dynamic>> shareholders =
        List<Map<String, dynamic>>.from(data['shareholders'] ?? []);

    try {
      // 1️⃣ Update main orders collection
      await _firestore.collection('orders').doc(orderId).set({
        ...data,
        'paymentStatus': paymentMethod == 'online' ? 'paid' : 'pending',
        'processingStatus': 'Pending',
        'deliveryStatus': 'Pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2️⃣ Update admin_orders collection
      await _firestore.collection('admin_orders').doc(orderId).set({
        'adminId': data['adminId'],
        'orderId': orderId,
        'userId': userId,
        'delivery_person_id': data['deliveryPersonId'],
        'shareholders': shareholders,
        'contact_details': data['contactDetails'],
        'delivery_address': data['deliveryAddress'],
        'qurbani_day': data['qurbaniDay'],
        'payment_status': paymentMethod == 'online' ? 'Done' : 'Cash Pending',
        'processing_status': 'Pending',
        'delivery_status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Deduct shares from animals
      Map<String, int> animalShareDeduction = {};
      for (var s in shareholders) {
        final animalId = s['animalId'] as String;
        animalShareDeduction[animalId] = (animalShareDeduction[animalId] ?? 0) + 1;
      }

      for (var entry in animalShareDeduction.entries) {
        final ref = _firestore.collection('animals').doc(entry.key);
        final sharesToDeduct = entry.value;

        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) return;

          final currentShares = snap['shares'] ?? 0;
          final newShares = currentShares - sharesToDeduct;

          tx.update(ref, {
            'shares': newShares < 0 ? 0 : newShares,
            'isAvailable': newShares > 0,
          });
        });
      }

      // 4️⃣ Clear user cart
      final cartRef = _firestore.collection('carts').doc(userId).collection('items');
      final cartSnap = await cartRef.get();
      for (var doc in cartSnap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Finalize order error: $e");
    }
  }

  Future<void> _checkIfAlreadyRated() async {
    try {
      final doc = await _firestore
          .collection('ratings')
          .doc(widget.orderData['orderId'])
          .get();
      if (doc.exists) setState(() => _ratingSubmitted = true);
    } catch (_) {}
  }

  Future<void> _submitRating() async {
    if (_ratingSubmitted || productRating == 0 || deliveryRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide both ratings")),
      );
      return;
    }

    await _firestore
        .collection('ratings')
        .doc(widget.orderData['orderId'])
        .set({
          'orderId': widget.orderData['orderId'],
          'userId': widget.orderData['userId'],
          'adminId': widget.orderData['adminId'],
          'deliveryPersonId': widget.orderData['deliveryPersonId'],
          'productRating': productRating,
          'productReview': productReviewController.text.trim(),
          'deliveryRating': deliveryRating,
          'deliveryReview': deliveryReviewController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

    setState(() => _ratingSubmitted = true);
  }

  Widget _starRow(double value, Function(double) onUpdate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < value ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: _ratingSubmitted ? null : () => onUpdate(i + 1.0),
        );
      }),
    );
  }

  /// Generate PDF receipt from shareholders
  Future<File> generateReceiptPDF(Map<String, dynamic> orderData) async {
    final pdf = pw.Document();
    final List<Map<String, dynamic>> shareholders =
        List<Map<String, dynamic>>.from(orderData['shareholders'] ?? []);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Receipt', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 10),
              pw.Text('Order ID: ${orderData['orderId']}'),
              pw.Text('User: ${orderData['userId']}'),
              pw.Text('Amount: ₹${orderData['totalAmount']}'),
              pw.SizedBox(height: 10),
              pw.Text('Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.ListView.builder(
                itemCount: shareholders.length,
                itemBuilder: (context, index) {
                  final s = shareholders[index];
                  return pw.Text(
                    '${index + 1}. ${s['animalType']} - Shareholder: ${s['name']} '
                    '(Parent: ${s['parentName']}, Gender: ${s['gender']})',
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt_${orderData['orderId']}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderData['orderId'];
    final amount = widget.orderData['totalAmount'];
    final paymentMethod = widget.orderData['paymentMethod'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Confirmed"),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 100, color: Colors.green),
                  const SizedBox(height: 15),
                  const Text(
                    "Thank You for Your Order!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text("Order ID: $orderId", textAlign: TextAlign.center),
                  Text("Amount: ₹$amount", textAlign: TextAlign.center),
                  Text("Payment: $paymentMethod", textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Download Receipt"),
                    onPressed: () async {
                      final file = await generateReceiptPDF(widget.orderData);
                      await OpenFilex.open(file.path);
                      await Share.shareXFiles([XFile(file.path)]);
                    },
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text("Back to Home"),
                    onPressed: () {
                      final userId = widget.orderData['userId'] as String;
                      final userName =
                          widget.orderData['userName']?.toString() ?? 'User';

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomePage(id: userId, name: userName),
                        ),
                        (_) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  if (!_ratingSubmitted) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text("Rate Product / Qurbani Service"),
                            _starRow(
                              productRating,
                              (v) => setState(() => productRating = v),
                            ),
                            TextField(
                              controller: productReviewController,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: "Write a review (optional)",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text("Rate Delivery Person"),
                            _starRow(
                              deliveryRating,
                              (v) => setState(() => deliveryRating = v),
                            ),
                            TextField(
                              controller: deliveryReviewController,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: "Delivery feedback (optional)",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitRating,
                      child: const Text("Submit Rating"),
                    ),
                  ] else
                    const Text(
                      "⭐ You have already rated this order",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
