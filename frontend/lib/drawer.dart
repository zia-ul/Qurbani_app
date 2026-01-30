import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Qurbani/authentication/login_page.dart';
import 'package:Qurbani/services/auth_service.dart';

// Admin Pages
import 'package:Qurbani/screens/admin/animal_listing.dart';
import 'package:Qurbani/screens/admin/slot_management.dart';

// User Pages
import 'package:Qurbani/profile_page.dart';
import 'package:Qurbani/screens/user/reset_password_page.dart';
import 'package:Qurbani/screens/user/user_special_request.dart';
import 'package:Qurbani/screens/user/invite_friend_page.dart';
import 'package:Qurbani/screens/user/qurbani_feature_page.dart'; // Assuming AboutUsPage is here

// Delivery Pages
// import 'package:Qurbani/screens/delivery/delivery_settings.dart';
import 'package:Qurbani/services/service_profile.dart';
import 'package:Qurbani/settings_page.dart';

class MasterDrawer extends StatelessWidget {
  final String name;
  final String id;
  final String role; // 'admin', 'delivery', 'user'

  const MasterDrawer({
    super.key,
    required this.name,
    required this.id,
    required this.role,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<String?> _getProfilePicture() async {
    try {
      final profile = await ProfileService.getProfile();
      // print("profileeeee....$profile");
      return profile['photo_url'] ??
          profile['photoUrl'] ??
          profile['profile_image'] ??
          profile['image'];
    } catch (e) {
      debugPrint("Error fetching profile picture: $e");
      return null;
    }
  }

  String _getWelcomeText() {
    switch (role) {
      case 'admin':
        return "Welcome Admin";
      case 'delivery':
        return "Welcome Delivery";
      case 'user':
        return "Welcome";
      default:
        return "Welcome";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.accentGreen),
            child: Row(
              children: [
                FutureBuilder<String?>(
                  future: _getProfilePicture(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 35,
                        backgroundColor: AppTheme.bgGradientEnd,
                        child: CircularProgressIndicator(
                          color: AppTheme.accentGreen,
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final img = snapshot.data;
                    return CircleAvatar(
                      radius: 35,
                      backgroundColor: AppTheme.bgGradientEnd,
                      backgroundImage: (img != null && img.isNotEmpty)
                          ? NetworkImage(img)
                          : null,
                      child: (img == null || img.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: AppTheme.accentGreen,
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getWelcomeText(),
                        style: const TextStyle(
                          color: AppTheme.bgGradientEnd,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.bgGradientEnd,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        id.length > 8 ? "${id.substring(0, 8)}..." : id,
                        style: const TextStyle(
                          color: AppTheme.bgGradientEnd,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          if (role == 'admin') ...[
            _drawerItem(context, Icons.person, "Profile", ProfilePage()),
            _drawerItem(
              context,
              Icons.assignment,
              "Animal Inventory",
              AnimalListingPage(),
            ),
            _drawerItem(
              context,
              Icons.lock_reset,
              "Reset Password",
              const ResetPasswordPage(),
            ),
            _drawerItem(
              context,
              Icons.settings,
              "Settings",
              SettingsPage(userId: id, role: role),
            ),
            _drawerItem(
              context,
              Icons.person_add,
              "Invite Friend",
              const InviteFriendPage(),
            ),
            _drawerItem(
              context,
              Icons.star,
              "Qurbani Features",
              const AboutUsPage(),
            ),
          ] else if (role == 'pending') ...[
            _drawerItem(context, Icons.person, "Profile", ProfilePage()),

            _drawerItem(
              context,
              Icons.lock_reset,
              "Reset Password",
              const ResetPasswordPage(),
            ),
            _drawerItem(
              context,
              Icons.person_add,
              "Invite Friend",
              const InviteFriendPage(),
            ),
            _drawerItem(
              context,
              Icons.star,
              "Qurbani Features",
              const AboutUsPage(),
            ),
          ] else if (role == 'delivery') ...[
            // _drawerItem(context, Icons.settings, "Settings", const SettingsPage()),
            _drawerItem(context, Icons.person, "Profile", const ProfilePage()),
            _drawerItem(
              context,
              Icons.lock_reset,
              "Reset Password",
              const ResetPasswordPage(),
            ),
            _drawerItem(
              context,
              Icons.person_add,
              "Invite Friend",
              const InviteFriendPage(),
            ),
            _drawerItem(
              context,
              Icons.star,
              "Qurbani Features",
              const AboutUsPage(),
            ),
          ] else if (role == 'user') ...[
            _drawerItem(context, Icons.person, "Profile", const ProfilePage()),
            _drawerItem(
              context,
              Icons.settings,
              "Settings",
              SettingsPage(userId: id, role: role),
            ),
            _drawerItem(
              context,
              Icons.lock_reset,
              "Reset Password",
              const ResetPasswordPage(),
            ),
            _drawerItem(
              context,
              Icons.assignment,
              "Special Requests",
              MySpecialRequestsPage(),
            ),
            _drawerItem(
              context,
              Icons.person_add,
              "Invite Friend",
              const InviteFriendPage(),
            ),
            _drawerItem(
              context,
              Icons.star,
              "Qurbani Features",
              const AboutUsPage(),
            ),
          ],

          const Spacer(),

          // Logout
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.warningRed),
            title: const Text("Logout", style: TextStyle(color: AppTheme.warningRed)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await _logout(context);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
