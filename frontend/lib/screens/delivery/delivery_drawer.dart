import 'package:flutter/material.dart';
import 'package:qurbani/authentication/login_page.dart';
import 'package:qurbani/services/auth_service.dart';
import 'package:qurbani/screens/delivery/delivery_settings.dart'; 
import 'package:qurbani/services/service_profile.dart'; 

class DeliveryDrawer extends StatelessWidget {
  final String deliveryName;
  final String deliveryId;

  const DeliveryDrawer({
    super.key,
    required this.deliveryName,
    required this.deliveryId,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<String?> _getDeliveryProfilePicture() async {
    try {
      final profile = await ProfileService.getProfile();
      return profile['photoUrl'];
    } catch (e) {
      // Handle error silently
      return null;
    }
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
                // Profile Picture
                FutureBuilder<String?>(
                  future: _getDeliveryProfilePicture(),
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

                    if (profilePicture != null && profilePicture.isNotEmpty) {
                      return CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(profilePicture),
                      );
                    } else {
                      return CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xff537D4F),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 20),

                // Delivery Name and Welcome Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Delivery",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deliveryName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deliveryId.substring(0, 8) + "...",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
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
              if (confirm == true) await _logout(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}