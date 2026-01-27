/**
 * Login Page Widget
 *
 * This screen handles user authentication for the Qurbani application.
 * It provides a form-based login interface with email and password fields,
 * including validation, error handling, and navigation to the main app.
 *
 * Features:
 * - Email and password input validation
 * - Password visibility toggle
 * - Loading states during authentication
 * - Error handling with user-friendly dialogs
 * - Navigation to registration page
 * - Automatic redirect to wrapper screen on successful login
 */

import 'package:flutter/material.dart';
import 'package:Qurbani/wrapper_screen.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'package:Qurbani/theme/theme.dart';

/**
 * LoginScreen Widget
 *
 * A stateful widget that displays the login form with email and password fields.
 * Handles user authentication flow and navigation upon successful login.
 */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/**
 * State class for LoginScreen
 *
 * Manages the login form state including form validation, loading states,
 * password visibility toggle, and authentication logic.
 */
class _LoginScreenState extends State<LoginScreen> {
  // Form controllers for managing input field values
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Global key for form validation
  final _formKey = GlobalKey<FormState>();

  // State variables for UI management
  bool _isLoading = false;        // Controls loading spinner during authentication
  bool _obscurePassword = true;   // Controls password field visibility


  // LOGIN FUNCTION
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Login (JWT saved inside AuthService)
      await AuthService.login({'email': email, 'password': password});

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WrapperScreen()),
        (route) => false,
      );

      // Go to WrapperScreen
      // Navigator.of(context).pushNamedAndRemoveUntil(
      //   '/wrapper',
      //   (route) => false,
      // );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Login Error"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 15,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8E6D1), Color(0xFFDBD299)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Log In",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.email_outlined),
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'Enter a valid email',
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.lock_outline),
                              labelText: 'Password',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
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
                                : 'Password must be at least 6 chars',
                          ),
                          const SizedBox(height: 20),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Log In"),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don’t have an account? "),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                                child: const Text(
                                  "Sign up",
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
