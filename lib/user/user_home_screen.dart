import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:qurbani1/login_page.dart';
import 'package:qurbani1/user/animal_grid_list.dart';
import 'package:qurbani1/user/booked_page.dart';
import 'package:qurbani1/user/cart_badge.dart';
import 'package:qurbani1/user/drawer_menu.dart';

class HomePage extends StatelessWidget {
  final String id;   // Firebase UID
  final String name; // User name (passed from Wrapper)

  const HomePage({
    super.key,
    required this.id,
    required this.name,
  });

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // Wrapper will auto-redirect
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          CartBadge(userId: id),
        ],
      ),

      drawer: AppDrawer(
        userName: name,
        userId: id,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            /// HEADER
            Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.lightGreen],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  const Icon(Icons.home, size: 100, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome Back, $name!",
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Book your Qurbani easily and conveniently. "
                    "A dedicated platform for livestock traders, farmers, "
                    "and hobbyists to buy, sell and share animals online.",
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            /// ACTIONS
            Container(
              margin: const EdgeInsets.all(50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "Your Actions",
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookedPage(userId: id),
                        ),
                      );
                    },
                    style: _outlinedGreenButton(),
                    child: const Text("Booked", style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnimalGridPage(),
                        ),
                      );
                    },
                    style: _outlinedGreenButton(),
                    child:
                        const Text("New Booking", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _outlinedGreenButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.green,
      side: const BorderSide(color: Colors.green, width: 0.8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
