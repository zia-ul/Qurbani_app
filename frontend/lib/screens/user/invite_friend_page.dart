import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qurbani/theme/theme.dart';

class InviteFriendPage extends StatelessWidget {
  const InviteFriendPage({super.key});

  void _inviteFriend() {
    Share.share(
      '🐄 Join me on Qurbani App!\n\n'
      'Buy Qurbani animals easily, track orders, and get fresh delivery.\n\n'
      'Download now 👉 https://yourapp.link',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invite Friends"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// ICON (Telegram-style minimal)
            const Icon(
              Icons.person_add_alt_1,
              size: 90,
              color: AppTheme.primaryGreen,
            ),

            const SizedBox(height: 20),

            /// TITLE
            const Text(
              "Invite friends to Qurbani",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            /// DESCRIPTION
            const Text(
              "Help your friends perform Qurbani easily.\n"
              "Share the app and make their experience smooth and trusted.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppTheme.primaryGreen),
            ),

            const SizedBox(height: 30),

            /// BENEFITS (like Telegram)
            _benefitTile("✔ Trusted sellers"),
            _benefitTile("✔ Fresh & hygienic delivery"),
            _benefitTile("✔ Order tracking"),
            _benefitTile("✔ Share-based Qurbani"),

            const Spacer(),

            /// INVITE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text("Invite Friend"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: _inviteFriend,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// SMALL BENEFIT ROW
  static Widget _benefitTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
