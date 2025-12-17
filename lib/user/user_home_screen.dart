import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/login_page.dart';
import 'package:qurbani1/user/animal_grid_list.dart';
import 'package:qurbani1/user/booked_page.dart';
import 'package:qurbani1/user/cart_badge.dart';
import 'package:qurbani1/user/cart_page.dart';
import 'package:qurbani1/user/drawer_menu.dart';

class HomePage extends StatelessWidget {
  final String id; // Firebase UID

  const HomePage({super.key, required this.id});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'User';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [CartBadge(userId: id)],
          ),

          drawer: AppDrawer(userName: name, userId: id),

          body: SingleChildScrollView(
            child: Column(
              children: [
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
                  child: Center(
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
                          "Book your Qurbani easily and conveniently. A dedicated platform for livestock traders, farmers, and hobbyists to buy, sell and share their animals online.",
                          style: TextStyle(fontSize: 14, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

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
                        child: const Text(
                          "Booked",
                          style: TextStyle(fontSize: 16),
                        ),
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
                        child: const Text(
                          "New Booking",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () => logout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _outlinedGreenButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.green,
      side: const BorderSide(color: Colors.green, width: 2),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
