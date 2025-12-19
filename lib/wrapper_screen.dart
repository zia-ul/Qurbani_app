import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:qurbani1/welcome_screen.dart';
import 'package:qurbani1/admin/admin_home_page.dart';
import 'package:qurbani1/delivery/delivery_home_page.dart';
import 'package:qurbani1/user/user_home_screen.dart';

class WrapperScreen extends StatelessWidget {
  const WrapperScreen({super.key});

  Future<Widget> _getHomeForUser(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      // Safety fallback
      await FirebaseAuth.instance.signOut();
      return const WelcomeScreen();
    }

    final data = doc.data()!;
    final role = data['role'] ?? 'user';
    final name = data['name'] ?? 'User';

    if (role == 'pending_admin') {
      await FirebaseAuth.instance.signOut();
      return const WelcomeScreen();
    }

    if (role == 'admin') {
      return AdminHomePage(
        adminId: user.uid,
        name: name,
      );
    }

    if (role == 'delivery') {
      return DeliveryHomePage(
        deliveryId: user.uid,
        name: name,
      );
    }

    // Default user
    return HomePage(
      id: user.uid,
      name: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 🔄 Auth loading
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not logged in
        if (!authSnapshot.hasData) {
          return const WelcomeScreen();
        }

        // ✅ Logged in → resolve role
        final user = authSnapshot.data!;

        return FutureBuilder<Widget>(
          future: _getHomeForUser(user),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return roleSnapshot.data ?? const WelcomeScreen();
          },
        );
      },
    );
  }
}
