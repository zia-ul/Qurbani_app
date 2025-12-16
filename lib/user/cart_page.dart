import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/animal_details.dart';
import 'package:qurbani1/user/proceed_page.dart';

class CartPage extends StatefulWidget {
  final String userId;

  const CartPage({super.key, required this.userId});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _removing = false;
  bool _updatingQty = false;

  Stream<QuerySnapshot> get cartStream {
    return _firestore
        .collection('carts')
        .doc(widget.userId)
        .collection('items')
        .snapshots();
  }

  /// 🗑 Remove item
  Future<void> removeItem(String animalId) async {
    if (_removing) return;
    _removing = true;

    try {
      await _firestore
          .collection('carts')
          .doc(widget.userId)
          .collection('items')
          .doc(animalId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    _removing = false;
  }

  /// ➕➖ Update quantity
  Future<void> updateCartQuantity(String animalId, int newQty) async {
    if (_updatingQty) return;
    _updatingQty = true;

    try {
      final ref = _firestore
          .collection('carts')
          .doc(widget.userId)
          .collection('items')
          .doc(animalId);

      if (newQty <= 0) {
        await ref.delete();
      } else {
        await ref.update({'qty': newQty});
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    _updatingQty = false;
  }

  /// ❌ Empty cart
  Future<void> emptyCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Empty Cart"),
        content: const Text("Are you sure you want to remove all items?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('carts')
        .doc(widget.userId)
        .collection('items')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// 🛒 Cart Item UI
  Widget buildCartItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final int qty = (data['qty'] ?? 1).toInt();
    final double price = (data['price'] ?? 0).toDouble();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Image.network(
          data['imageUrl'] ?? '',
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 40),
        ),
        title: Text(
          data['title'] ?? 'Animal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.red),
              onPressed: () => updateCartQuantity(doc.id, qty - 1),
            ),
            Text(
              "$qty",
              style: const TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.green),
              onPressed: () => updateCartQuantity(doc.id, qty + 1),
            ),
            const SizedBox(width: 8),
            Text(
              "₹ ${(price * qty).toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),

        /// ✅ FIXED OVERFLOW HERE
        trailing: SizedBox(
          width: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.remove_red_eye,
                    size: 20, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AnimalDetailPage(animalId: doc.id),
                    ),
                  );
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete,
                    size: 20, color: Colors.red),
                onPressed: () => removeItem(doc.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No items in cart"));
          }

          /// 🧮 Totals
          int totalQty = 0;
          double totalAmount = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final int qty = (data['qty'] ?? 1).toInt();
            final double price = (data['price'] ?? 0).toDouble();

            totalQty += qty;
            totalAmount += price * qty;
          }

          return Column(
            children: [
              /// 🧾 CART SUMMARY
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Quantity"),
                          Text(
                            "$totalQty",
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Total Amount"),
                          Text(
                            "₹ ${totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// 🛒 ITEMS
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) => buildCartItem(docs[i]),
                ),
              ),

              /// 🔘 ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: emptyCart,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Empty Cart"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final cartItems = docs
                              .map((doc) =>
                                  (doc.data() as Map<String, dynamic>)
                                    ..['animal_id'] = doc.id)
                              .toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProceedPage(
                                cartItems: cartItems,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text("Proceed"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
