import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CartService {
  static bool _isProcessing = false;

  /// Add an animal to the user's cart
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
          .collection('carts') // top-level carts
          .doc(user.uid)
          .collection('items')
          .doc(animalId);

      // Safe image URL
      final String imageUrl = _safeImageUrl(animalData['photoUrl']);

      // Ensure price is numeric
      final dynamic rawPrice = animalData['price'];
      final double price = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '0') ?? 0;

      await firestore.runTransaction((transaction) async {
        // Read animal and cart first
        final animalSnap = await transaction.get(animalRef);
        final cartSnap = await transaction.get(cartRef);

        if (!animalSnap.exists) throw Exception("Animal not found");

        final data = animalSnap.data()!;
        final rawQty = data['qty'];
        final int currentQty = rawQty is int
            ? rawQty
            : int.tryParse(rawQty?.toString() ?? '0') ?? 0;

        if (currentQty <= 0) throw Exception("Out of stock");

        // Decrement stock
        transaction.update(animalRef, {'qty': currentQty - 1});

        // Add or update cart item
        if (cartSnap.exists) {
          final int cartQty = (cartSnap.data()?['qty'] ?? 1) as int;
          transaction.update(cartRef, {'qty': cartQty + 1});
        } else {
          transaction.set(cartRef, {
            'animalId': animalId,
            'title': animalData['title'] ?? animalData['type'] ?? 'Animal',
            'price': price,
            'qty': 1,
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

  /// Safely validate image URL
  static String _safeImageUrl(dynamic url) {
    if (url == null) return '';
    if (url is! String) return '';
    if (url.trim().isEmpty) return '';
    if (!url.startsWith('http')) return '';
    return url;
  }
}
