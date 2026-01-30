import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/drawer.dart';

class PendingAdminScreen extends StatelessWidget {
  final String id;
  final String name;
  final String role;
  final String? verification;

  const PendingAdminScreen({
    super.key,
    required this.id,
    required this.name,
    required this.role,
    required this.verification,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Verification")),
      drawer: MasterDrawer(id: id, name: name, role: role),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
              SizedBox(height: 20),
              Text(
                "Your admin verification is pending",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "Please wait while we review your documents.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RejectedAdminScreen extends StatelessWidget {
  const RejectedAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, size: 80, color: AppTheme.warningRed),
              SizedBox(height: 20),
              Text(
                "Admin verification rejected",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "Please contact support or re-submit documents.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
