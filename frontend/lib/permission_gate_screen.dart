import 'package:flutter/material.dart';
// import 'package:Qurbani/role_router.dart';
import 'package:Qurbani/wrapper_screen.dart';
import '../permission_service.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  @override
  void initState() {
    super.initState();
    _handle();
  }

  Future<void> _handle() async {
    final granted = await PermissionService.requestPermissions();

    if (granted && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WrapperScreen()),
      );
      return;
    }

    final permanent = await PermissionService.permanentlyDenied();
    if (permanent && mounted) {
      _showSettingsDialog();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
          "Please enable location and storage permissions in settings.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              PermissionService.openSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
