import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/screens/user/payment_success_page.dart';
import 'package:qurbani/theme/theme.dart';
import 'package:qurbani/widgets/success_error_popup.dart';
import 'razorpay_integration.dart'; // Ensure this path is correct

class ReviewOrderPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const ReviewOrderPage({super.key, required this.orderData});

  @override
  State<ReviewOrderPage> createState() => _ReviewOrderPageState();
}

class _ReviewOrderPageState extends State<ReviewOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isPlacingOrder = false;

  final Color parchmentBg = const Color(0xFFF4F7F4);

  // 1. Declare the Razorpay Handler
  late RazorPayIntegration _razorpayHandler;

  @override
  void initState() {
    super.initState();
    // 2. Initialize Razorpay Handler
    _razorpayHandler = RazorPayIntegration();
    _razorpayHandler.init(ctx: context, data: widget.orderData);
  }

  @override
  void dispose() {
    // 3. Clean up Razorpay resources
    _razorpayHandler.dispose();
    super.dispose();
  }

  // --- BARCODE GENERATOR LOGIC ---
  String generateBarcodeValue({required String animalId}) {
    final raw = animalId.replaceAll(RegExp(r'[^0-9]'), '');
    final base = raw.padRight(12, '0').substring(0, 12);
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(base[i]);
      sum += (i.isEven) ? digit : digit * 3;
    }
    final checksum = (10 - (sum % 10)) % 10;
    return '$base$checksum';
  }

  // --- SLOT BOOKING LOGIC ---
  Future<void> _markSlotAsBooked(
    String adminId,
    String day,
    String slotTime,
  ) async {
    final dayKey = day.toLowerCase(); // Matches "day 1", "day 2" etc.
    final eidDocRef = _firestore.collection("eidSlots").doc(adminId);
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
        tx.set(userDocRef, {
          'usersSlots': {dayKey: slots},
        }, SetOptions(merge: true));
      }
    });
  }

  // --- MAIN PLACEMENT LOGIC ---
  Future<void> _placeOrder() async {
    setState(() => isPlacingOrder = true);

    try {
      final String orderId =
          "QB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
      final String userId = widget.orderData['userId'];
      final String adminId = widget.orderData['adminId'];
      final List cartItems = widget.orderData['cartItems'];
      final List shareholders = widget.orderData['shareholders'];

      // 1. Finalize Order Object with proper structure
      final finalOrder = Map<String, dynamic>.from(widget.orderData);
      finalOrder['orderId'] = orderId;
      finalOrder['paymentStatus'] = finalOrder['paymentMethod'] == 'online'
          ? 'Paid'
          : 'Pending';
      finalOrder['processingStatus'] = 'Pending';
      finalOrder['deliveryStatus'] = 'Pending';
      finalOrder['isCompleted'] = false; // Important for admin display
      finalOrder['createdAt'] = FieldValue.serverTimestamp();
      finalOrder['items'] =
          cartItems; // Ensure items field exists for admin display

      // 2. Create Records with proper error handling
      await _firestore.collection('orders').doc(orderId).set(finalOrder);

      // Alternative: Create admin order without notification flags to avoid permission issues
      try {
        await _firestore.collection('admin_orders').doc(orderId).set({
          ...finalOrder,
          'newOrderPlaced': true, // Mark as new for admin notification
          'ratingReceived': false,
          'deliveryStatusUpdated': false,
          'userProcessingNotified': false,
          'userDeliveryNotified': false,
        });
      } catch (e) {
        print("Admin order creation failed (permission issue): $e");
        // Fallback: Create a simplified admin order without notification flags
        try {
          await _firestore.collection('admin_orders').doc(orderId).set({
            ...finalOrder,
            'newOrderPlaced': true,
          });
        } catch (fallbackError) {
          print("Fallback admin order creation also failed: $fallbackError");
          // If admin order creation fails completely, continue with order placement
          // The order will still be visible to admins through the main orders collection
        }
      }

      // 3. Process Share Deduction & Barcode Generation with better error handling
      for (var item in cartItems) {
        try {
          final animalRef = _firestore
              .collection('animals')
              .doc(item['animalId']);

          await _firestore.runTransaction((tx) async {
            final snap = await tx.get(animalRef);
            if (!snap.exists) {
              throw Exception("Animal not found: ${item['animalId']}");
            }

            int currentShares = (snap['shares'] ?? 0).toInt();
            int boughtShares = (item['shares'] ?? 1).toInt();
            int updatedShares = (currentShares - boughtShares) < 0
                ? 0
                : (currentShares - boughtShares);

            Map<String, dynamic> updateData = {
              'shares': updatedShares,
              'isAvailable': updatedShares > 0,
            };

            // Generate Barcode if animal is now fully sold
            if (updatedShares == 0 && snap.data()?['barcode'] == null) {
              updateData['barcode'] = generateBarcodeValue(
                animalId: item['animalId'],
              );
              updateData['barcodeGeneratedAt'] = FieldValue.serverTimestamp();
            }

            tx.update(animalRef, updateData);
          });
        } catch (e) {
          print("Error updating animal shares: $e");
          // Continue with other items even if one fails
        }
      }

      // 4. Mark Eid Slots as Booked with better error handling
      for (var s in shareholders) {
        if (s['preferredDay'] != null && s['selectedSlot'] != null) {
          try {
            await _markSlotAsBooked(
              adminId,
              s['preferredDay'],
              s['selectedSlot'],
            );
          } catch (e) {
            print("Error booking slot: $e");
          }
        }
      }

      // 5. Clear Cart with proper error handling
      try {
        final cartSnap = await _firestore
            .collection('carts')
            .doc(userId)
            .collection('items')
            .get();
        for (var doc in cartSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        print("Error clearing cart: $e");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(
            orderData: {...finalOrder, 'orderId': orderId},
          ),
        ),
      );
    } catch (e) {
      ToastUtils.showError("Placement Error: $e");
    } finally {
      setState(() => isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List cartItems = widget.orderData['cartItems'] ?? [];
    return Scaffold(
      backgroundColor: parchmentBg,
      appBar: AppBar(
        title: const Text(
          "Review Order",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepperHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummarySection(
                    title: "Selected Animals",
                    icon: Icons.pets,
                    child: Column(
                      children: cartItems
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "${item['animalType']} - ${item['breed'] ?? 'Pure'}",
                              ),
                              subtitle: Text(
                                "Selected Shares: ${item['shares']}",
                              ),
                              trailing: Text(
                                "₹${item['price']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _buildSummarySection(
                    title: "Delivery Information",
                    icon: Icons.local_shipping_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Address: ${widget.orderData['deliveryLocation']['address']}",
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Phone: ${widget.orderData['contact']['primary']}",
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  _buildSummarySection(
                    title: "Payment Method",
                    icon: Icons.credit_score,
                    child: Text(
                      widget.orderData['paymentMethod'] == 'cod'
                          ? "Cash on Delivery"
                          : "Online Payment",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTotalCard(),
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildStepperHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem("1", "Details", true, true),
          _stepLine(true),
          _stepItem("2", "Payment", true, true),
          _stepLine(true),
          _stepItem("3", "Review", true, false),
        ],
      ),
    );
  }

  Widget _stepItem(String num, String label, bool active, bool completed) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: completed
              ? AppTheme.primaryGreen
              : (active ? AppTheme.primaryGreen : Colors.grey[300]),
          child: completed
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  num,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppTheme.primaryGreen : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(
      height: 2,
      color: active ? AppTheme.primaryGreen : Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 15),
    ),
  );

  Widget _buildSummarySection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD1C4A9).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Grand Total",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          Text(
            "₹${widget.orderData['totalAmount']}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    bool isOnline = widget.orderData['paymentMethod'] == 'online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: isPlacingOrder
                ? null
                : () async {
                    if (isOnline) {
                      await _razorpayHandler.startPayment();
                    } else {
                      await _placeOrder();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isPlacingOrder
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "Confirm & Place Order",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
