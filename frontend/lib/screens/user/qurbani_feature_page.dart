import 'package:flutter/material.dart';
import 'package:Qurbani/theme/theme.dart';

/// ===============================================================
/// ABOUT US & FEATURES PAGE (Card-based Design)
/// ===============================================================
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<AboutFeature> features = const [
      AboutFeature(
        icon: Icons.shopping_cart,
        title: "Online Qurbani Booking",
        description:
            "Book Qurbani shares digitally using a simple and user-friendly interface.",
      ),
      AboutFeature(
        icon: Icons.pets,
        title: "Multiple Animal Support",
        description:
            "Supports Goat & Sheep (single share) and Camel & Buffalo (multiple shares).",
      ),
      AboutFeature(
        icon: Icons.payment,
        title: "Cash & Online Payments",
        description:
            "Flexible payment options including online payment and Cash.",
      ),
      AboutFeature(
        icon: Icons.lock,
        title: "Secure OTP Authentication",
        description:
            "OTP-based login ensures safe and authorized access to the application.",
      ),
      AboutFeature(
        icon: Icons.track_changes,
        title: "Real-Time Status Tracking",
        description:
            "Track Qurbani progress, meat processing, and delivery status live.",
      ),
      AboutFeature(
        icon: Icons.qr_code,
        title: "Barcode Identification",
        description:
            "Each animal is tagged with a barcode for complete transparency.",
      ),
      AboutFeature(
        icon: Icons.admin_panel_settings,
        title: "Admin Control Panel",
        description:
            "Admins manage animals, shares, barcodes, and delivery efficiently.",
      ),
      AboutFeature(
        icon: Icons.local_shipping,
        title: "Delivery Management",
        description:
            "Authorized delivery staff confirm meat delivery with proper tracking.",
      ),
      AboutFeature(
        icon: Icons.receipt_long,
        title: "Receipts & Notifications",
        description:
            "Digital receipts and automatic notifications after booking & payment.",
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F4),
      appBar: AppBar(
        title: const Text("About Qurbani App"),
        backgroundColor: AppTheme.primaryGreen,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// ---------------- ABOUT HEADER ----------------
          // const Text(
          //   "About Us",
          //   style: TextStyle(
          //     fontSize: 20,
          //     fontWeight: FontWeight.bold,
          //     color: AppTheme.primaryGreen,
          //   ),
          // ),
          // const SizedBox(height: 8),
          const Text(
            "The Qurbani App is a digital platform designed to manage the entire "
            "Qurbani process—from booking and payments to delivery tracking—"
            "with transparency and efficiency.",
            style: TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.justify,
          ),

          const SizedBox(height: 20),

          /// ---------------- FEATURES ----------------
          const Text(
            "Key Features",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          ...features.map(
            (feature) => Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryGreen,
                      child: Icon(
                        feature.icon,
                        color: Color.fromARGB(255, 255, 255, 255),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// ---------------- APP VERSION ----------------
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              "App Version v1.0.0",
              style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// ===============================================================
/// FEATURE MODEL
/// ===============================================================
class AboutFeature {
  final IconData icon;
  final String title;
  final String description;

  const AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
