import 'package:flutter/material.dart';
import 'package:qurbani/onboarding_screen.dart';
import 'package:qurbani/screens/admin/admin_home_page.dart';
import 'package:qurbani/screens/user/user_home_screen.dart';
import 'package:qurbani/welcome_screen.dart';
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
    // print("WrapperScreen: Checking current user...$_userFuture");
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
          // No user logged in → show onboarding
          return const OnboardingScreen();
        }

        final user = snapshot.data!;
        print("WrapperScreen: Logged in as ${user.role} (${user.name})");

        // Route based on role
        switch (user.role) {
          case 'admin':
            return AdminHomePage(adminId: user.id.toString(), name: user.name);
          case 'user':
            print("WrapperScreen: Logged in as ${user.role} (${user.name})");

            return HomePage(
              id: user.id.toString(),
              name: user.name,
              role: user.role,
            );
          case 'pending_admin':
            return const WelcomeScreen();
          default:
            return const WelcomeScreen();
        }
      },
    );
  }
}
