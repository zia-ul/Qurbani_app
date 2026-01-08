
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qurbani/authentication/login_page.dart';
import 'package:qurbani/screens/user/profile_page.dart';
import 'package:qurbani/screens/user/qurbani_feature_page.dart';
import 'package:qurbani/screens/user/invite_friend_page.dart';
import 'package:qurbani/screens/user/settings_page.dart';
import 'package:qurbani/screens/user/reset_password_page.dart';
import 'package:qurbani/screens/user/user_special_request.dart';
import '../../services/auth_service.dart';

class UserDrawer extends StatelessWidget {
  final String userName;
  final String userId;

  const UserDrawer({super.key, required this.userName, required this.userId});

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

  Future<String?> _getUserProfilePicture() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // Check for various possible field names for flexibility
          return data['photoUrl'] ??
              data['profilePicture'] ??
              data['profileImageUrl'] ??
              data['imageUrl'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile picture: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xff537D4F)),
            child: Row(
              children: [
                // Profile Picture Section
                FutureBuilder<String?>(
                  future: _getUserProfilePicture(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(
                          color: Color(0xff537D4F),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final profilePicture = snapshot.data;

                    return CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          (profilePicture != null && profilePicture.isNotEmpty)
                          ? NetworkImage(profilePicture)
                          : null,
                      child: (profilePicture == null || profilePicture.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: Color(0xff537D4F),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 15),

                // User Info Section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userId.length > 8
                            ? "${userId.substring(0, 8)}..."
                            : userId,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation List
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.settings),
          //   title: const Text("Settings"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const SettingsPage()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.lock_reset, color: Color(0xff537D4F)),
          //   title: const Text("Reset Password"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.assignment),
          //   title: const Text("Special Requests"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => MySpecialRequestsPage()),
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.person_add, color: Color(0xff537D4F)),
            title: const Text("Invite Friend"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteFriendPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star, color: Color(0xff537D4F)),
            title: const Text("Qurbani Features"),
            onTap: () {
              Navigator.pop(context);
              // Note: Ensure AboutUsPage is the correct class name in qurbani_feature_page.dart
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutUsPage()),
              );
            },
          ),

          const Spacer(),

          // Logout Section
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
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
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.red),
                      ),
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
}
