import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qurbani1/login_page.dart';
import 'package:qurbani1/admin/add_aminal.dart';
import 'package:qurbani1/admin/admin_orders.dart';
import 'package:qurbani1/admin/animal_listing.dart';
import 'package:qurbani1/admin/special_requests_admin.dart';

class AdminHomePage extends StatelessWidget {
  final String adminId;
  final String name;

  const AdminHomePage({super.key, required this.adminId, required this.name});

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Welcome, $name"),
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.green),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Animal Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnimalListingPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text('Bookings'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => logout(context),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top container - fixed height
            Container(
              height: 400, // fixed height
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
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
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Welcome Back, $name!",
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Manage bookings and animal stock easily from this dashboard.",
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddAnimalPage(),
                        ),
                      );
                    },
                    style: _outlinedGreenButton(),
                    child: const Text(
                      "Stock of Animals",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminOrdersPage(adminId: adminId),
                        ),
                      );
                    },
                    style: _outlinedGreenButton(),
                    child: const Text(
                      "Bookings",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminSpecialRequestsPage(),
                        ),
                      );
                    },
                    style: _outlinedGreenButton(),
                    child: const Text(
                      "Special Requests",
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
  }

  ButtonStyle _outlinedGreenButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.green,
      side: const BorderSide(color: Colors.green, width: 2),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
