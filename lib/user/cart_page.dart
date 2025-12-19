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

  Stream<QuerySnapshot> get cartStream => _firestore
      .collection('carts')
      .doc(widget.userId)
      .collection('items')
      .snapshots();

  Future<void> _updateShares(String animalId, int newShares) async {
    if (newShares <= 0) {
      await removeItem(animalId);
      return;
    }

    await _firestore
        .collection('carts')
        .doc(widget.userId)
        .collection('items')
        .doc(animalId)
        .update({'shares': newShares});
  }

  Future<void> removeItem(String animalId) async {
    await _firestore
        .collection('carts')
        .doc(widget.userId)
        .collection('items')
        .doc(animalId)
        .delete();
  }

  Future<void> emptyCart() async {
    final snap = await _firestore
        .collection('carts')
        .doc(widget.userId)
        .collection('items')
        .get();
    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  /// 🛒 CART ITEM WIDGET
  Widget buildCartItem(DocumentSnapshot cartDoc) {
    final cart = cartDoc.data() as Map<String, dynamic>;
    final int cartShares = (cart['shares'] ?? 1).toInt();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('animals').doc(cartDoc.id).snapshots(),
      builder: (context, snapshot) {
        bool available = false;
        int availableShares = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final animal = snapshot.data!.data() as Map<String, dynamic>;
          available =
              animal['isAvailable'] == true && (animal['shares'] ?? 0) > 0;
          availableShares = (animal['shares'] ?? 0).toInt();

          // Auto-adjust cart shares if stock reduced
          if (cartShares > availableShares) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateShares(cartDoc.id, availableShares);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "${cart['title']} shares adjusted to $availableShares due to stock change",
                  ),
                ),
              );
            });
          }
        }

        final bool isUnavailable =
            !snapshot.hasData || !snapshot.data!.exists || !available;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isUnavailable ? Colors.red : Colors.green),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                /// 🔹 TOP ROW
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          cart['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cart['title'] ?? 'Animal',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isUnavailable
                                ? "Unavailable"
                                : "Shares: $cartShares / $availableShares",
                            style: TextStyle(
                                color: isUnavailable ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "₹ ${(cart['price'] * cartShares).toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// ➕➖ SHARE CONTROLS
                if (!isUnavailable)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: cartShares > 1
                            ? () => _updateShares(cartDoc.id, cartShares - 1)
                            : null,
                      ),
                      Text(
                        "$cartShares",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: cartShares < availableShares
                            ? () => _updateShares(cartDoc.id, cartShares + 1)
                            : null,
                      ),
                    ],
                  ),

                const Divider(color: Colors.grey),

                /// 🔘 ACTIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.remove_red_eye),
                      label: const Text("View"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AnimalDetailPage(animalId: cartDoc.id)),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        "Remove",
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () => removeItem(cartDoc.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shopping Cart"),
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
            return const Center(
              child: Text(
                "Your cart is empty",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          int totalQty = 0;
          double totalAmount = 0;

          for (var d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final int shares = (data['shares'] ?? 0).toInt();
            final double price = (data['price'] ?? 0).toDouble();

            totalQty += shares;
            totalAmount += price * shares;
          }

          return Column(
            children: [
              /// 🔝 TOTAL (fixed)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Items"),
                        Text(
                          "$totalQty",
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
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

              /// 🏷 Scrollable cart items
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) => buildCartItem(docs[i]),
                ),
              ),
            ],
          );
        },
      ),

      /// 🟢 STICKY BOTTOM BUTTONS
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey, width: 0.3)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: cartStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final bool hasInvalid = docs.any((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['shares'] ?? 0) == 0;
              });
              final bool isEmpty = docs.isEmpty;

              return Row(
                children: [
                  /// 🗑 EMPTY CART
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isEmpty ? null : emptyCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Empty Cart",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// ✅ PROCEED
                  Expanded(
                    child: ElevatedButton(
                      onPressed: hasInvalid || isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProceedPage(
                                    userId: widget.userId,
                                    cartItems: docs
                                        .map((e) =>
                                            e.data() as Map<String, dynamic>)
                                        .toList(),
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Proceed",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
