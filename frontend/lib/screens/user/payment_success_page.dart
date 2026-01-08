import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/user/user_home_screen.dart'; // Ensure this points to your HomePage
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

  @override
  void initState() {
    super.initState();
    _finalizeOrderOnce();
  }

  /// Marks a single slot as booked in eidSlots, users, and all admin animals
  Future<void> _markSlotAsBooked(
    String adminId,
    String day,
    String slotTime,
  ) async {
    // Note: Your DB uses "day 1", "day 2", etc. (with a space)
    final dayKey = day.toLowerCase();

    // 1. Update main eidSlots collection
    final eidDocRef = _firestore.collection("eidSlots").doc(adminId);

    // 2. Update admin user's private document
    final userDocRef = _firestore.collection("users").doc(adminId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(eidDocRef);
      if (!snap.exists) return;

      final Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
      final List slots = List.from(data[dayKey] ?? []);

      bool found = false;
      for (var s in slots) {
        if (s['time'] == slotTime && s['status'] == 'Free') {
          s['status'] = 'Booked';
          found = true;
          break;
        }
      }

      if (found) {
        tx.update(eidDocRef, {dayKey: slots});
        // Also sync to user's "usersSlots" field
        tx.set(userDocRef, {
          'usersSlots': {dayKey: slots},
        }, SetOptions(merge: true));
      }
    });

    // 3. Update all animals belonging to this admin to show correct live slots
    final animalsSnapshot = await _firestore
        .collection("animals")
        .where("adminId", isEqualTo: adminId)
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in animalsSnapshot.docs) {
      final Map<String, dynamic> adminSlots = Map<String, dynamic>.from(
        doc.data()['adminSlots'] ?? {},
      );
      final List slots = List.from(adminSlots[dayKey] ?? []);

      for (var s in slots) {
        if (s['time'] == slotTime) {
          s['status'] = 'Booked';
          break;
        }
      }
      adminSlots[dayKey] = slots;
      batch.update(doc.reference, {'adminSlots': adminSlots});
    }
    await batch.commit();
  }

  Future<void> _finalizeOrderOnce() async {
    if (_processed) return;
    _processed = true;

    final data = widget.orderData;
    final String orderId = data['orderId'];
    final String userId = data['userId'];
    final String adminId =
        data['adminId']; // Assuming adminId is passed in orderData
    final List shareholders = data['shareholders'] ?? [];

    try {
      // 1. Create the user-side order record
      await _firestore.collection('orders').doc(orderId).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Create the admin-side order record
      await _firestore.collection('admin_orders').doc(orderId).set({
        ...data,
        'newOrderPlaced': false,
        'ratingReceived': false,
        'deliveryStatusUpdated': false,
        'userProcessingNotified': false,
        'userDeliveryNotified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. DEDUCT SHARES FROM ANIMALS
      for (var item in data['cartItems']) {
        final animalRef = _firestore
            .collection('animals')
            .doc(item['animalId']);
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(animalRef);
          if (!snap.exists) return;
          int current = (snap['shares'] ?? 0).toInt();
          int bought = (item['shares'] ?? 1).toInt();
          tx.update(animalRef, {
            'shares': (current - bought) < 0 ? 0 : (current - bought),
          });
        });
      }

      // 4. MARK CHOSEN SLOTS AS BOOKED
      for (var s in shareholders) {
        final day = s['preferredDay']; // e.g., "Day 1"
        final time = s['selectedSlot']; // e.g., "7:46 PM"

        if (day != null && time != null) {
          await _markSlotAsBooked(adminId, day, time);
        }
      }

      // 5. CLEAR CART
      final cartItems = await _firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .get();
      for (var doc in cartItems.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Finalization Error: $e");
    }
  }

  Future<File> generateReceiptPDF() async {
    final pdf = pw.Document();
    final order = widget.orderData;

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Qurbani Receipt",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text("Order ID: ${order['orderId']}"),
            pw.Text("Total Amount: ${order['totalAmount']}"),
            pw.SizedBox(height: 10),
            pw.Text("Shareholders:", style: pw.TextStyle(fontSize: 18)),
            ...List.generate(order['shareholders'].length, (i) {
              final s = order['shareholders'][i];
              return pw.Bullet(
                text:
                    "${s['name']} - Slot: ${s['preferredDay']} at ${s['selectedSlot']}",
              );
            }),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/receipt_${order['orderId']}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 120,
                color: Color(0xff3D6B4E),
              ),
              const SizedBox(height: 20),
              const Text(
                "Success!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff2D4F32),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Order ID: ${widget.orderData['orderId']}",
                style: const TextStyle(fontSize: 16, color: Color(0xff537D4F)),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Download & Share Receipt"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3D6B4E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final file = await generateReceiptPDF();
                    await OpenFilex.open(file.path);
                    await Share.shareXFiles([XFile(file.path)]);
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.home),
                label: const Text("Go Back to Dashboard"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff3D6B4E),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        id: widget.orderData['userId'],
                        name: widget.orderData['userName'] ?? 'User',
                        role: 'user',
                      ),
                    ),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
