import 'package:flutter/material.dart';
import 'package:Qurbani/onboarding_screen.dart';
import 'package:Qurbani/screens/admin/admin_home_page.dart';
import 'package:Qurbani/screens/admin/admin_verification.dart';
import 'package:Qurbani/screens/admin/pending_admin.dart';
import 'package:Qurbani/screens/delivery/delivery_home_page.dart';
import 'package:Qurbani/screens/superadmin/superadmin_welcome_page.dart';
import 'package:Qurbani/screens/user/user_home_screen.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

class WrapperScreen extends StatefulWidget {
  const WrapperScreen({super.key});

  @override
  State<WrapperScreen> createState() => _WrapperScreenState();
}



class _WrapperScreenState extends State<WrapperScreen> {
  late Future<UserModel?> _userFuture;

  @override
  void initState() {
    super.initState();

    // Start centralized notifications
    // NotificationService.startPolling();

    // Check if user is logged in via JWT
    _userFuture = AuthService.getCurrentUser();
    print("WrapperScreen: Checking current user...$_userFuture");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _userFuture,
      builder: (context, snapshot) {
        print("WrapperScreen snapshot state: ${snapshot.connectionState}");
        print("WrapperScreen snapshot hasData: ${snapshot.hasData}");
        print("WrapperScreen snapshot data: ${snapshot.data}");
        print("WrapperScreen snapshot error: ${snapshot.error}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          // No user logged in, then show onboarding
          return const OnboardingScreen();
        }

        final user = snapshot.data!;
        print("WrapperScreen: Logged in as ${user.role} (${user.name})");

        // Route based on role
        switch (user.role) {
          case 'user':
            return HomePage(id: user.id, name: user.name, role: user.role);

          case 'delivery':
            return DeliveryHomePage(deliveryId: user.id, name: user.name);

          case 'admin':
            final status = user.verificationStatus;

            // No submission yet
            if (status == null || status == 'not_submitted') {
              return AdminVerificationPage(
                id: user.id,
                name: user.name,
                role: user.role,
                verification: user.verificationStatus,
              );
            }

            // Submitted, waiting
            if (status == 'pending') {
              return PendingAdminScreen(
                id: user.id,
                name: user.name,
                role: user.role,
                verification: user.verificationStatus,
              );
            }

            // Approved admin
            if (status == 'approved') {
              return AdminHomePage(adminId: user.id, name: user.name);
            }

            // Rejected or unknown state
            return PendingAdminScreen(
              id: user.id,
              name: user.name,
              role: user.role,
              verification: user.verificationStatus,
            );

          case 'super_admin':
            return SuperAdminDashboard(id: user.id, name: user.name);

          default:
            return const OnboardingScreen();
        }
      },
    );
  }
}
