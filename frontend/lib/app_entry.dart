import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Qurbani/permission_gate_screen.dart';

import 'wrapper_screen.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  bool _navigated = false; // prevents double navigation

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _decide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _decide(); // re-check permissions when user returns from settings
    }
  }

  Future<void> _decide() async {
    if (_navigated) return;

    final permissionsGranted = await _checkPermissions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigated) return;
      _navigated = true;

      if (!permissionsGranted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PermissionGateScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WrapperScreen()),
        );
      }
    });
  }

  Future<bool> _checkPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.camera,
      Permission.photos, // Android 13+
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
