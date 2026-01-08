import 'package:flutter/material.dart';
import 'package:qurbani/authentication/login_page.dart';
import 'package:qurbani/screens/user/qurbani_feature_page.dart';
import 'package:qurbani/screens/user/invite_friend_page.dart';
import 'package:qurbani/screens/user/reset_password_page.dart';

class SuperadminDrawer extends StatelessWidget {
  // final String adminName;
  // final String adminId;

  const SuperadminDrawer({
    super.key,
    // required this.adminName,
    // required this.adminId,
  });

  // Future<void> _logout(BuildContext context) async {
  //   await FirebaseAuth.instance.signOut();
  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (_) => const LoginScreen()),
  //     (_) => false,
  //   );
  // }

  // Future<String?> _getAdminProfilePicture() async {
  //   try {
  //     final adminDoc = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(adminId)
  //         .get();

  //     if (adminDoc.exists) {
  //       final data = adminDoc.data()!;
  //       // Try multiple possible field names for profile picture
  //       return data['photoUrl'] ??
  //           data['profilePicture'] ??
  //           data['profileImageUrl'] ??
  //           data['imageUrl'] ??
  //           '';
  //     }
  //   } catch (e) {
  //     // Handle error silently or log it
  //   }
  //   return null;
  // }

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
                // Profile Picture
                // FutureBuilder<String?>(
                //   future: _getAdminProfilePicture(),
                //   builder: (context, snapshot) {
                //     if (snapshot.connectionState == ConnectionState.waiting) {
                //       return const CircleAvatar(
                //         radius: 35,
                //         backgroundColor: Colors.white,
                //         child: CircularProgressIndicator(
                //           color: Color(0xff537D4F),
                //           strokeWidth: 2,
                //         ),
                //       );
                //     }

                //     final profilePicture = snapshot.data;

                //     if (profilePicture != null && profilePicture.isNotEmpty) {
                //       return CircleAvatar(
                //         radius: 35,
                //         backgroundColor: Colors.white,
                //         backgroundImage: NetworkImage(profilePicture),
                //         child: profilePicture.isEmpty
                //             ? const Icon(
                //                 Icons.person,
                //                 size: 40,
                //                 color: Color(0xff537D4F),
                //               )
                //             : null,
                //       );
                //     } else {
                //       return CircleAvatar(
                //         radius: 35,
                //         backgroundColor: Colors.white,
                //         child: const Icon(
                //           Icons.person,
                //           size: 40,
                //           color: Color(0xff537D4F),
                //         ),
                //       );
                //     }
                //   },
                // ),
                // const SizedBox(width: 20),

                // Admin Name and Welcome Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Superadmin",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Text(
                      //   adminName,
                      //   style: const TextStyle(
                      //     color: Colors.white,
                      //     fontSize: 20,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   adminId.substring(0, 8) + "...",
                      //   style: const TextStyle(
                      //     color: Colors.white60,
                      //     fontSize: 12,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ListTile(
          //   leading: const Icon(Icons.person),
          //   title: const Text("Profile"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const ProfilePage()),
          //     );
          //   },
          // ),
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
          //   title: const Text("Animal Inventory"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => AnimalListingPage()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.assignment),
          //   title: const Text("Slot Management"),
          //   onTap: () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (_) => AdminSlotPage(
          //           adminId: FirebaseAuth.instance.currentUser!.uid,
          //         ),
          //       ),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutUsPage()),
              );
            },
          ),
          const Spacer(),
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
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              );
              // if (confirm == true) await _logout(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
