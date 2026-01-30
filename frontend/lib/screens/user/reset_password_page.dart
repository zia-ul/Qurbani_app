import 'package:flutter/material.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Qurbani/theme/theme.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      await AuthService.changePassword(currentPassword, newPassword);

      Fluttertoast.showToast(
        msg: "Password changed successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.primaryGreen,
        textColor: AppTheme.bgGradientEnd,
      );

      // Clear the form fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Navigate back to settings page
      Navigator.pop(context);
    } catch (e) {
      String errorMessage = "Failed to change password";

      // Map specific errors
      if (e.toString().contains("Current password is incorrect")) {
        errorMessage = "Current password is incorrect";
      } else if (e.toString().contains("User not found")) {
        errorMessage = "User not authenticated. Please login again.";
      } else if (e.toString().contains("weak")) {
        errorMessage =
            "New password is too weak. Please use a stronger password";
      } else {
        errorMessage = e.toString();
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.warningRed,
        textColor: AppTheme.bgGradientEnd,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Text(
          "Change Password",
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your current password and new password to update your account.",
                style: TextStyle(fontSize: 16, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 30),

              // Current Password Field
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgGradientEnd,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppTheme.primaryGreen,
                  ),
                  labelText: 'Current Password',
                  labelStyle: const TextStyle(color: AppTheme.primaryGreen),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
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
              const SizedBox(height: 20),

              // New Password Field
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgGradientEnd,
                  prefixIcon: const Icon(
                    Icons.lock,
                    color: AppTheme.primaryGreen,
                  ),
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: AppTheme.primaryGreen),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.primaryGreen,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  if (value == _currentPasswordController.text) {
                    return 'New password must be different from current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirm New Password Field
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgGradientEnd,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppTheme.primaryGreen,
                  ),
                  labelText: 'Confirm New Password',
                  labelStyle: const TextStyle(color: AppTheme.primaryGreen),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppTheme.primaryGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.primaryGreen,
                    ),
                    onPressed: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
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
                          "Change Password",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.bgGradientEnd,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Note: Your password must be at least 6 characters long.",
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
