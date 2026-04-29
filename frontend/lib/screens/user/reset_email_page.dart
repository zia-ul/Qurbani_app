import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/services/service_profile.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ResetEmailPage extends StatefulWidget {
  final String currentEmail;

  const ResetEmailPage({super.key, required this.currentEmail});

  @override
  State<ResetEmailPage> createState() => _ResetEmailPageState();
}

class _ResetEmailPageState extends State<ResetEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentEmailController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;

  @override
  void initState() {
    super.initState();
    _currentEmailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ProfileService.updateEmail(
        currentPassword: _currentPasswordController.text.trim(),
        newEmail: _newEmailController.text.trim(),
      );

      Fluttertoast.showToast(
        msg: "Email updated successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryGreen,
        textColor: AppTheme.bgGradientEnd,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e, stack) {
      AppLogger.error("Email update failed", e, stack);
      final message = e is ApiException
          ? e.message
          : e.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');

      Fluttertoast.showToast(
        msg: message.isEmpty ? "Failed to update email" : message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.warningRed,
        textColor: AppTheme.bgGradientEnd,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppTheme.bgGradientEnd,
      prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.primaryGreen),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppTheme.primaryGreen),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppTheme.primaryGreen),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Text(
          "Change Email",
          style: TextStyle(color: AppTheme.bgGradientEnd),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.bgGradientEnd),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "Enter your current password and new email to update your account.",
                style: TextStyle(fontSize: 16, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _currentEmailController,
                readOnly: true,
                decoration: _decoration(
                  label: "Current Email",
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  label: "New Email",
                  icon: Icons.mark_email_read_outlined,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Please enter your new email';
                  if (!_isValidEmail(email)) {
                    return 'Please enter a valid email';
                  }
                  if (email.toLowerCase() ==
                      _currentEmailController.text.trim().toLowerCase()) {
                    return 'New email must be different from current email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  label: "Confirm New Email",
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Please confirm your new email';
                  if (email.toLowerCase() !=
                      _newEmailController.text.trim().toLowerCase()) {
                    return 'Emails do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: _decoration(
                  label: "Current Password",
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.primaryGreen,
                    ),
                    onPressed: () {
                      setState(
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.bgGradientEnd,
                          ),
                        )
                      : const Text(
                          "Change Email",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.bgGradientEnd,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
