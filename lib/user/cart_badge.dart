import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani1/user/cart_page.dart';

class CartBadge extends StatelessWidget {
  final String userId;
  final Color iconColor;

  const CartBadge({
    super.key,
    required this.userId,
    this.iconColor = Colors.white,
  });

  Stream<int> _cartItemCountStream() {
    return FirebaseFirestore.instance
        .collection('carts')
        .doc(userId)
        .collection('items')
        .snapshots()
        .map((snapshot) {
      int totalShares = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final shares = data['shares'];

        if (shares is int) {
          totalShares += shares;
        } else if (shares is num) {
          totalShares += shares.toInt();
        } else {
          totalShares += 1; // safe fallback
        }
      }

      return totalShares;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _cartItemCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.shopping_cart, color: iconColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartPage(userId: userId),
                  ),
                );
              },
            ),

            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
