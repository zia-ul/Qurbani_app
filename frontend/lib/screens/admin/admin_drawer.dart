import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:qurbani/screens/admin/slot_management.dart';
import 'package:qurbani/authentication/login_page.dart';
import 'package:qurbani/screens/admin/animal_listing.dart';
import 'package:qurbani/screens/user/profile_page.dart';
import 'package:qurbani/screens/user/qurbani_feature_page.dart';
import 'package:qurbani/screens/user/invite_friend_page.dart';
import 'package:qurbani/screens/user/settings_page.dart';
import 'package:qurbani/screens/user/reset_password_page.dart';

import '../../services/auth_service.dart';

class AdminDrawer extends StatelessWidget {
  final String adminName;
  final String adminId; // UUID from backend

  const AdminDrawer({
    super.key,
    required this.adminName,
    required this.adminId,
  });

  // ---------------------------------------------------------
  // BACKEND LOGOUT (JWT)
  // ---------------------------------------------------------
  Future<void> _logout(BuildContext context) async {
    await AuthService.logout(); // clears JWT token

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ---------------------------------------------------------
  // PROFILE IMAGE (Firestore only for media)
  // ---------------------------------------------------------
  Future<String?> _getAdminProfilePicture() async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();

      if (adminDoc.exists) {
        final data = adminDoc.data()!;
        return data['photoUrl'] ??
            data['profilePicture'] ??
            data['profileImageUrl'] ??
            data['imageUrl'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ---------------------------------------------------------
          // HEADER
          // ---------------------------------------------------------
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xff537D4F)),
            child: Row(
              children: [
                FutureBuilder<String?>(
                  future: _getAdminProfilePicture(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    final img = snapshot.data;
                    return CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          (img != null && img.isNotEmpty)
                              ? NetworkImage(img)
                              : null,
                      child: (img == null || img.isEmpty)
                          ? const Icon(Icons.person,
                              size: 40, color: Color(0xff537D4F))
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Admin",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${adminId.substring(0, 8)}...",
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // MENU ITEMS
          // ---------------------------------------------------------
          _drawerItem(
            context,
            icon: Icons.person,
            title: "Profile",
            page: const ProfilePage(),
          ),
          // _drawerItem(
          //   context,
          //   icon: Icons.settings,
          //   title: "Settings",
          //   page: const SettingsPage(),
          // ),
          // _drawerItem(
          //   context,
          //   icon: Icons.lock_reset,
          //   title: "Reset Password",
          //   page: const ResetPasswordPage(),
          // ),
          // _drawerItem(
          //   context,
          //   icon: Icons.assignment,
          //   title: "Animal Inventory",
          //   page: AnimalListingPage(),
          // ),
          _drawerItem(
            context,
            icon: Icons.assignment,
            title: "Slot Management",
            page: AdminSlotPage(adminId: adminId), // ✅ FIXED
          ),
          _drawerItem(
            context,
            icon: Icons.person_add,
            title: "Invite Friend",
            page: const InviteFriendPage(),
          ),
          _drawerItem(
            context,
            icon: Icons.star,
            title: "Qurbani Features",
            page: const AboutUsPage(),
          ),

          const Spacer(),

          // ---------------------------------------------------------
          // LOGOUT
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Logout"),
                  content:
                      const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _logout(context);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // DRAWER ITEM HELPER
  // ---------------------------------------------------------
  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}
