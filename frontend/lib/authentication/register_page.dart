/**
 * Registration Page Widget
 *
 * This screen handles new user registration for the Qurbani application.
 * It provides a comprehensive form with multiple fields including personal
 * information, contact details, password creation, and role selection.
 *
 * Features:
 * - Multi-field registration form with validation
 * - Password strength checking and confirmation
 * - International phone number input
 * - Terms and conditions acceptance
 * - Role-based registration (User/Admin/Delivery)
 * - Email verification flow after registration
 * - Currency preference selection
 * - Gender selection
 * - Address collection
 */

import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:Qurbani/authentication/login_page.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/terms_condition_dialog.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';

/**
 * RegisterPage Widget
 *
 * A stateful widget that displays the comprehensive user registration form.
 * Handles new user account creation with multiple validation steps and
 * navigation to email verification upon successful registration.
 */
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/**
 * State class for RegisterPage
 *
 * Manages the complex registration form state including form validation,
 * password strength checking, terms acceptance, and user registration flow.
 * Handles multiple input controllers and state variables for form management.
 */
class _RegisterPageState extends State<RegisterPage> {
  // Global form key for validation management
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers for form input fields
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();
  final addressController = TextEditingController();

  // User selection and preference variables
  String selectedRole = 'user'; // Default role selection
  String? selectedGender; // Gender selection (Male/Female)
  bool termsAccepted = false; // Terms and conditions acceptance flag
  bool isLoading = false; // Loading state during registration
  String passwordStrength = ""; // Real-time password strength indicator
  bool _obscureConfirmPassword = true; // Password confirmation field visibility

  // Phone number handling variables
  String? countryCode; // +91
  String? phoneNumber; // 9876543210

  String? countryISO; // Country ISO code for phone validation
  String selectedCurrency = 'USD'; // Default currency preference

  // ---------------- PASSWORD ----------------
  String _checkPasswordStrength(String password) {
    if (password.length < 8) return "Too short";
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$&*~]'));
    if (hasUpper && hasLower && hasDigit && hasSpecial) return "Strong";
    if ((hasUpper || hasLower) && hasDigit) return "Medium";
    return "Weak";
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#\$&*~]'));
  }

  // ---------------- TERMS ----------------
  Future<void> _openTerms() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
    );
    if (accepted != null) setState(() => termsAccepted = accepted);
  }

  // ---------------- REGISTER ----------------
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      AppLogger.warning('Register form validation failed');
      return;
    }

    _formKey.currentState!.save();

    if (phoneNumber == null || countryCode == null) {
      AppLogger.warning('Register failed: phone number missing');
      ToastUtils.showError('Please enter phone number');
      return;
    }

    if (!termsAccepted) {
      AppLogger.warning('Register failed: terms not accepted');
      ToastUtils.showError('Please accept Terms & Conditions');
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService.register({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "password": passController.text.trim(),
        "phone": phoneNumber,
        "country_code": countryCode,
        "country_iso": countryISO,
        "address": addressController.text.trim(),
        "gender": selectedGender,
        "role": selectedRole,
        "currency": selectedCurrency,
      });

      if (!mounted) return;

      AppLogger.info('User registered successfully');

      ToastUtils.showSuccess(
        'Registration successful. Please verify your email.',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } catch (e, stack) {
      AppLogger.error('Register API failed', e, stack);
      ToastUtils.showError(
        "${e.toString().replaceAll('Exception:', '').trim()}",
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    bool? isObscured,
    VoidCallback? toggleObscure,
    String? helperText,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: TextFormField(
        controller: controller,
        obscureText: isObscured ?? obscure,
        onChanged: onChanged,
        keyboardType: label == "Phone Number"
            ? TextInputType.phone
            : TextInputType.text,
        validator:
            validator ??
            (v) => v == null || v.trim().isEmpty ? "$label is required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color.fromARGB(255, 255, 255, 255),
          labelText: label,
          helperText: helperText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          prefixIcon: Icon(icon, color: Color(int.parse('0xff537D4F'))),
          suffixIcon: toggleObscure != null
              ? IconButton(
                  icon: Icon(
                    (isObscured ?? true)
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: toggleObscure,
                )
              : null,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passController.dispose();
    confirmPassController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image (same as login)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Optional semi-transparent overlay
          // Container(color: Colors.black.withOpacity(0.3)),

          // Scrollable content
          SingleChildScrollView(
            child: SizedBox(
              // height: MediaQuery.of(context).size.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Optional logo at top
                  // SizedBox(
                  //   height: 200,
                  //   width: 200,
                  //   child: Image.asset(
                  //     'assets/images/app_app_logo.png',
                  //     fit: BoxFit.contain,
                  //   ),
                  // ),
                  const SizedBox(height: 15),

                  // Form Card
                  SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FractionallySizedBox(
                              widthFactor: 0.85,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation:
                                    15, // Increase elevation for a bigger shadow
                                shadowColor: const Color.fromARGB(255, 0, 0, 0),
                                // color: AppTheme.bgGradientEnd,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE8E6D1), // light beige
                                        Color.fromARGB(
                                          255,
                                          219,
                                          210,
                                          153,
                                        ), // dark green
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20.0),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      textTheme: const TextTheme(
                                        bodyMedium: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                        bodyLarge: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black,
                                        ),
                                      ),
                                      inputDecorationTheme:
                                          const InputDecorationTheme(
                                            labelStyle: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black,
                                            ),
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            "CREATE ACCOUNT",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          // const Text(
                                          //   "Fresh Qurbani, Delivered to Your Doorstep",
                                          //   textAlign: TextAlign.center,
                                          // ),
                                          // const SizedBox(height: 20),

                                          // Name Field
                                          _field(
                                            nameController,
                                            "Full Name",
                                            Icons.person,
                                          ),

                                          const SizedBox(height: 5),

                                          // Gender Dropdown
                                          DropdownButtonFormField<String>(
                                            initialValue: selectedGender,
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'Male',
                                                child: Text(
                                                  'Male',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Female',
                                                child: Text(
                                                  'Female',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => selectedGender = v,
                                            ),
                                            decoration: const InputDecoration(
                                              filled: true,
                                              fillColor: AppTheme.bgGradientEnd,
                                              labelText: "Gender",
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(12),
                                                ),
                                              ),
                                            ),
                                            validator: (v) => v == null
                                                ? "Please select gender"
                                                : null,
                                          ),

                                          const SizedBox(height: 8),

                                          // Email Field
                                          _field(
                                            emailController,
                                            "Email",
                                            Icons.email_outlined,
                                            validator: (v) => v!.contains("@")
                                                ? null
                                                : "Invalid email",
                                          ),

                                          const SizedBox(height: 5),

                                          // Phone Field
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: IntlPhoneField(
                                              controller: phoneController,
                                              initialCountryCode: 'IN',
                                              onSaved: (phone) {
                                                phoneNumber = phone?.number;
                                                countryCode =
                                                    phone?.countryCode;
                                                countryISO =
                                                    phone?.countryISOCode;
                                              },
                                              onChanged: (phone) {
                                                phoneNumber = phone.number;
                                                countryCode = phone.countryCode;
                                                countryISO =
                                                    phone.countryISOCode;
                                              },
                                              validator: (phone) {
                                                if (phone == null ||
                                                    phone.number.isEmpty) {
                                                  return 'Phone number is required';
                                                }
                                                if (!phone.isValidNumber()) {
                                                  return 'Invalid phone number';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),

                                          // Address
                                          _field(
                                            addressController,
                                            "Address",
                                            Icons.location_on,
                                          ),

                                          const SizedBox(height: 5),

                                          // Password
                                          _field(
                                            passController,
                                            "Password",
                                            Icons.lock_outline,
                                            helperText:
                                                "Min 8 chars, 1 upper, 1 lower, 1 number, 1 special\nExample: Abc@1234",
                                            onChanged: (v) {
                                              setState(() {
                                                passwordStrength =
                                                    _checkPasswordStrength(v);
                                              });
                                            },
                                            validator: (v) =>
                                                _isPasswordValid(v!)
                                                ? null
                                                : "Invalid password",
                                          ),

                                          const SizedBox(height: 5),

                                          // Confirm Password
                                          _field(
                                            confirmPassController,
                                            "Confirm Password",
                                            Icons.lock_outline,
                                            isObscured: _obscureConfirmPassword,
                                            toggleObscure: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                            validator: (v) =>
                                                v != passController.text
                                                ? "Passwords do not match"
                                                : null,
                                          ),

                                          if (passwordStrength.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                "Password strength: $passwordStrength",
                                                style: TextStyle(
                                                  color:
                                                      passwordStrength ==
                                                          "Strong"
                                                      ? Color(
                                                          int.parse(
                                                            '0xff537D4F',
                                                          ),
                                                        )
                                                      : AppTheme.warningRed,
                                                ),
                                              ),
                                            ),

                                          const SizedBox(height: 5),

                                          // Role Dropdown
                                          DropdownButtonFormField<String>(
                                            initialValue: selectedRole,
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'user',
                                                child: Text(
                                                  "User",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'admin',
                                                child: Text(
                                                  "Admin",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'delivery',
                                                child: Text(
                                                  "Delivery",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => selectedRole = v!,
                                            ),
                                            decoration: const InputDecoration(
                                              filled: true,
                                              fillColor: AppTheme.bgGradientEnd,
                                              labelText: "Register As",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(12),
                                                ),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),

                                          const SizedBox(height: 5),

                                          // Terms
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: termsAccepted,
                                                onChanged: (_) => _openTerms(),
                                                activeColor: Color(
                                                  int.parse('0xff537D4F'),
                                                ),
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: _openTerms,
                                                  child: const Text(
                                                    "I agree to the Terms & Conditions",
                                                    style: TextStyle(
                                                      decoration: TextDecoration
                                                          .underline,
                                                      color:
                                                          AppTheme.primaryGreen,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 5),

                                          // Register button
                                          ElevatedButton(
                                            onPressed: isLoading
                                                ? null
                                                : _register,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(
                                                int.parse('0xff537D4F'),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: isLoading
                                                ? const CircularProgressIndicator(
                                                    color:
                                                        AppTheme.bgGradientEnd,
                                                  )
                                                : const Text(
                                                    "Register",
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                          ),

                                          const SizedBox(height: 5),

                                          GestureDetector(
                                            onTap: () =>
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LoginScreen(),
                                                  ),
                                                ),
                                            child: const Text(
                                              "Already have an account? Login",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ),
                              // ),),
                              // const SizedBox(height: 50),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
