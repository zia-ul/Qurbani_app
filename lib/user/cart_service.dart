import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CartService {
  static bool _isProcessing = false;

  /// Add an animal to the user's cart
  /// Shares are NOT reduced here
  static Future<void> addAnimalToCart({
    required String animalId,
    required Map<String, dynamic> animalData,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final firestore = FirebaseFirestore.instance;
      final animalRef = firestore.collection('animals').doc(animalId);
      final cartRef = firestore
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .doc(animalId);

      final String imageUrl = _safeImageUrl(
        animalData['imageUrl'] ?? animalData['photoUrl'],
      );
      final double price = _safePrice(animalData['price']);

      await firestore.runTransaction((transaction) async {
        final animalSnap = await transaction.get(animalRef);
        final cartSnap = await transaction.get(cartRef);

        if (!animalSnap.exists) {
          throw Exception("Animal not found");
        }

        final animalDataDb = animalSnap.data()!;
        final bool isAvailable = animalDataDb['isAvailable'] ?? true;
        final int availableShares = (animalDataDb['shares'] ?? 0).toInt();

        if (!isAvailable || availableShares <= 0) {
          throw Exception("Out of stock");
        }

        // 🛒 Add or update cart item
        if (cartSnap.exists) {
          final int currentShares =
              (cartSnap.data()?['shares'] ?? 1).toInt();

          if (currentShares + 1 > availableShares) {
            throw Exception("Not enough shares available");
          }

          transaction.update(cartRef, {
            'shares': currentShares + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(cartRef, {
            'animalId': animalId,
            'title': animalData['title'] ??
                animalData['type'] ??
                'Animal',
            'price': price,
            'shares': 1, // ✅ START WITH 1 SHARE
            'imageUrl': imageUrl,
            'adminId': animalData['adminId'],
            'adminName': animalData['adminName'] ?? 'Unknown',
            'addedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint("❌ Add to cart failed: $e");
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  /// Remove an animal from the cart
  static Future<void> removeAnimalFromCart({
    required String animalId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .doc(animalId);

    await cartRef.delete();
  }

  /// Get current user's cart items stream
  static Stream<QuerySnapshot> getCartItemsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .snapshots();
  }

  /// Safely validate image URL
  static String _safeImageUrl(dynamic url) {
    if (url == null) return '';
    if (url is! String) return '';
    if (url.trim().isEmpty) return '';
    if (!url.startsWith('http')) return '';
    return url;
  }

  /// Safely parse price
  static double _safePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    return double.tryParse(price.toString()) ?? 0;
  }
}
