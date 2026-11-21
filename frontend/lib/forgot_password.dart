import 'package:flutter/material.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/common_input_decoration.dart';
import 'package:Qurbani/widgets/primary_btn.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isCodeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Fluttertoast.showToast(msg: "Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await AuthService.forgotPassword(email);
      Fluttertoast.showToast(
        msg: msg,
        backgroundColor: AppTheme.primaryGreen,
        textColor: Colors.white,
      );
      setState(() => _isCodeSent = true);
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString().replaceAll("Exception: ", ""),
        backgroundColor: AppTheme.warningRed,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await AuthService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPass,
      );
      Fluttertoast.showToast(
        msg: msg,
        backgroundColor: AppTheme.primaryGreen,
        textColor: Colors.white,
      );
      if (mounted) {
        Navigator.pop(context); // Return to login screen
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString().replaceAll("Exception: ", ""),
        backgroundColor: AppTheme.warningRed,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/auth_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.15),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white.withOpacity(0.95),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 56,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isCodeSent ? 'Enter Verification Code' : 'Forgot Password',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCodeSent
                            ? 'Please check your email (${_emailController.text}) for the 6-digit code.'
                            : 'Enter your registered email address and we will send you a reset code.',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isCodeSent,
                        decoration: CommonInputDecoration.build(
                          'Enter your email',
                          label: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Please enter a valid email',
                      ),

                      if (!_isCodeSent) ...[
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Send Reset Code',
                          height: 48,
                          isLoading: _isLoading,
                          onPressed: _requestCode,
                        ),
                      ],

                      if (_isCodeSent) ...[
                        const SizedBox(height: 16),
                        // OTP Field
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: CommonInputDecoration.build(
                            '6-digit code',
                            label: 'Verification Code',
                            prefixIcon: const Icon(Icons.pin),
                          ),
                          validator: (v) => v != null && v.length == 6
                              ? null
                              : 'Enter 6-digit verification code',
                        ),
                        const SizedBox(height: 12),

                        // New Password
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscurePassword,
                          decoration: CommonInputDecoration.build(
                            'Enter new password',
                            label: 'New Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 6
                              ? null
                              : 'Password must be at least 6 characters',
                        ),
                        const SizedBox(height: 12),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          decoration: CommonInputDecoration.build(
                            'Confirm new password',
                            label: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          validator: (v) => v != null && v.length >= 6
                              ? null
                              : 'Please confirm your password',
                        ),
                        const SizedBox(height: 24),

                        PrimaryButton(
                          text: 'Reset Password',
                          height: 48,
                          isLoading: _isLoading,
                          onPressed: _resetPassword,
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () {
                            setState(() => _isCodeSent = false);
                          },
                          child: const Text('Change Email / Resend Code'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
