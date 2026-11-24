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
 * - Role-based registration (User/Admin)
 * - Email verification flow after registration
 * - Currency preference selection
 * - Gender selection
 * - Address collection
 */

import 'package:Qurbani/utils/logger.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:Qurbani/authentication/login_page.dart';
import 'package:Qurbani/authentication/otp_verification_page.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/terms_condition_dialog.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

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
  // final addressController = TextEditingController();
  final countryController = TextEditingController();
  final cityController = TextEditingController();
  final postalCodeController = TextEditingController();

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
  String? selectedCountryName;
  // String? selectedCity;

  // Pre-verification states
  bool emailVerified = false;
  bool phoneVerified = false;
  bool isSendingEmailOtp = false;
  bool isSendingPhoneOtp = false;

  List<csc.State> states = [];
  List<csc.City> cities = [];

  csc.State? selectedState;
  csc.City? selectedCity;

  // ---------------- PRE-VERIFICATION DIALOG ----------------
  Future<void> _showPreOtpDialog({
    required String title,
    required String identifier,
    required String type,
    required VoidCallback onVerified,
  }) async {
    final otpTextController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  type == 'email' ? Icons.email_outlined : Icons.phone_android,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter the 6-digit code sent to:\n$identifier",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (type != 'email')
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "💡 Simulation Mode: Use code 123456",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpTextController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "• • • • • •",
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: AppTheme.warningRed, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isVerifying
                    ? null
                    : () async {
                        final code = otpTextController.text.trim();
                        if (code.length != 6) {
                          setDialogState(() => dialogError = "Please enter 6 digits");
                          return;
                        }
                        setDialogState(() {
                          isVerifying = true;
                          dialogError = null;
                        });
                        try {
                          await AuthService.verifyPreOtp(identifier: identifier, otp: code);
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          onVerified();
                          ToastUtils.showSuccess("$title successful!");
                        } catch (err) {
                          setDialogState(() {
                            isVerifying = false;
                            dialogError = err.toString().replaceAll("Exception:", "").trim();
                          });
                        }
                      },
                child: isVerifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Verify", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleVerifyEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ToastUtils.showError("Please enter a valid email address first");
      return;
    }

    setState(() => isSendingEmailOtp = true);
    try {
      await AuthService.sendPreOtp(identifier: email, type: 'email');
      ToastUtils.showSuccess("Verification code sent to $email");
      if (!mounted) return;
      _showPreOtpDialog(
        title: "Verify Email",
        identifier: email,
        type: 'email',
        onVerified: () => setState(() => emailVerified = true),
      );
    } catch (e) {
      ToastUtils.showError(e.toString().replaceAll("Exception:", "").trim());
    } finally {
      if (mounted) setState(() => isSendingEmailOtp = false);
    }
  }

  Future<void> _handleVerifyPhone() async {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      ToastUtils.showError("Please enter phone number first");
      return;
    }

    final fullPhone = "$countryCode $phoneNumber";
    setState(() => isSendingPhoneOtp = true);
    try {
      final res = await AuthService.sendPreOtp(identifier: fullPhone, type: 'phone');
      ToastUtils.showSuccess(res['message'] ?? "Verification code generated");
      if (!mounted) return;
      _showPreOtpDialog(
        title: "Verify Mobile",
        identifier: fullPhone,
        type: 'phone',
        onVerified: () => setState(() => phoneVerified = true),
      );
    } catch (e) {
      ToastUtils.showError(e.toString().replaceAll("Exception:", "").trim());
    } finally {
      if (mounted) setState(() => isSendingPhoneOtp = false);
    }
  }

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

        "country": selectedCountryName,
        "state": selectedState?.name,
        "city": selectedCity?.name,
        "postal_code": postalCodeController.text.trim(),

        "gender": selectedGender,
        "role": selectedRole,
        "currency": selectedCurrency,
      });

      if (!mounted) return;

      AppLogger.info('User registered successfully');

      final registeredEmail = emailController.text.trim();
      final registeredPhone = "$countryCode $phoneNumber";

      if (emailVerified) {
        ToastUtils.showSuccess("Registration successful! You can now log in.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        ToastUtils.showSuccess(
          "Registration successful. Please verify your account with the code sent to your email.",
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(
              email: registeredEmail,
              phone: registeredPhone,
            ),
          ),
        );
      };
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
    Widget? suffixWidget,
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
          suffixIcon: suffixWidget ?? (toggleObscure != null
              ? IconButton(
                  icon: Icon(
                    (isObscured ?? true)
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: toggleObscure,
                )
              : null),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  String? _validatePostalCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Postal code is required";
    }

    // India (PIN)
    if (countryISO == 'IN') {
      return RegExp(r'^[1-9][0-9]{5}$').hasMatch(value)
          ? null
          : "Enter valid 6-digit PIN code";
    }

    // USA
    if (countryISO == 'US') {
      return RegExp(r'^\d{5}(-\d{4})?$').hasMatch(value)
          ? null
          : "Enter valid ZIP code";
    }

    // Generic fallback
    if (value.length < 4) {
      return "Invalid postal code";
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passController.dispose();
    confirmPassController.dispose();
    // addressController.dispose();
    countryController.dispose();
    cityController.dispose();
    postalCodeController.dispose();
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

                                          // Email Field with Verify Button
                                          _field(
                                            emailController,
                                            "Email",
                                            Icons.email_outlined,
                                            validator: (v) => v!.contains("@")
                                                ? null
                                                : "Invalid email",
                                            onChanged: (_) {
                                              if (emailVerified) {
                                                setState(() => emailVerified = false);
                                              }
                                            },
                                            suffixWidget: Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: emailVerified
                                                  ? const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                                                        SizedBox(width: 4),
                                                        Text("Verified", style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ],
                                                    )
                                                  : TextButton(
                                                      onPressed: isSendingEmailOtp ? null : _handleVerifyEmail,
                                                      style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                      child: isSendingEmailOtp
                                                          ? const SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                                                            )
                                                          : const Text(
                                                              "Verify",
                                                              style: TextStyle(
                                                                color: AppTheme.primaryGreen,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                    ),
                                            ),
                                          ),

                                          const SizedBox(height: 5),

                                          // Phone Field with Verify Button
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                IntlPhoneField(
                                                  controller: phoneController,
                                                  initialCountryCode: "IN",
                                                  onSaved: (phone) {
                                                    phoneNumber = phone?.number;
                                                    countryCode =
                                                        phone?.countryCode;
                                                    countryISO =
                                                        phone?.countryISOCode;
                                                  },
                                                  onChanged: (phone) {
                                                    if (phoneVerified) {
                                                      setState(() => phoneVerified = false);
                                                    }
                                                    phoneNumber = phone.number;
                                                    countryCode = phone.countryCode;
                                                    countryISO =
                                                        phone.countryISOCode;

                                                    if (countryController
                                                        .text
                                                        .isEmpty) {
                                                      countryController.text =
                                                          phone.countryISOCode;
                                                    }
                                                  },

                                                  validator: (phone) {
                                                    if (phone == null ||
                                                        phone.number.isEmpty) {
                                                      return "Phone number is required";
                                                    }
                                                    if (!phone.isValidNumber()) {
                                                      return "Invalid phone number";
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2, right: 4),
                                                  child: phoneVerified
                                                      ? const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 18),
                                                            SizedBox(width: 4),
                                                            Text("Mobile Verified", style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                                          ],
                                                        )
                                                      : TextButton.icon(
                                                          onPressed: isSendingPhoneOtp ? null : _handleVerifyPhone,
                                                          style: TextButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          ),
                                                          icon: isSendingPhoneOtp
                                                              ? const SizedBox(
                                                                  width: 12,
                                                                  height: 12,
                                                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                                                                )
                                                              : const Icon(Icons.verified_outlined, size: 16, color: AppTheme.primaryGreen),
                                                          label: const Text(
                                                            "Verify Mobile",
                                                            style: TextStyle(
                                                              color: AppTheme.primaryGreen,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Address
                                          // _field(
                                          //   addressController,
                                          //   "Address",
                                          //   Icons.location_on,
                                          // ),
                                          // Country
                                          InkWell(
                                            onTap: () {
                                              showCountryPicker(
                                                context: context,
                                                onSelect: (country) async {
                                                  // Set selected country
                                                  setState(() {
                                                    selectedCountryName =
                                                        country.name;
                                                    countryISO =
                                                        country.countryCode;
                                                    countryController.text =
                                                        country.name;

                                                    // Reset state & city
                                                    selectedState = null;
                                                    selectedCity = null;
                                                    states = [];
                                                    cities = [];
                                                    cityController.clear();
                                                  });

                                                  // Load states for selected country
                                                  states = await csc
                                                      .getStatesOfCountry(
                                                        country.countryCode,
                                                      );

                                                  // Refresh UI
                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                },
                                              );
                                            },

                                            child: AbsorbPointer(
                                              child: _field(
                                                countryController,
                                                "Select Country",
                                                Icons.public,
                                                // helperText: "Select country",
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          DropdownButtonFormField<csc.State>(
                                            value: selectedState,
                                            isExpanded: true,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                            ),
                                            items: states
                                                .map(
                                                  (s) =>
                                                      DropdownMenuItem<
                                                        csc.State
                                                      >(
                                                        value: s,
                                                        child: Text(
                                                          s.name,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                        ),
                                                      ),
                                                )
                                                .toList(),
                                            onChanged: (value) async {
                                              setState(() {
                                                selectedState = value;
                                                selectedCity = null;
                                                cities = [];
                                                cityController.clear();
                                              });

                                              if (value != null) {
                                                cities = await csc
                                                    .getStateCities(
                                                      value.countryCode,
                                                      value.isoCode,
                                                    );
                                                if (mounted) setState(() {});
                                              }
                                            },
                                            decoration: const InputDecoration(
                                              labelText: "State",
                                              prefixIcon: Icon(Icons.map),
                                              filled: true,
                                              fillColor: Color.fromARGB(
                                                255,
                                                255,
                                                255,
                                                255,
                                              ), // ✅ THIS
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(12),
                                                ),
                                              ),
                                            ),
                                            validator: (v) {
                                              // If no states available → allow null
                                              if (states.isEmpty) return null;

                                              // States exist → selection required
                                              if (v == null) {
                                                return "Please select state";
                                              }
                                              return null;
                                            },
                                          ),

                                          // City
                                          // _field(
                                          //   cityController,
                                          //   "City for Qurbani Service",
                                          //   Icons.location_city,
                                          //   // helperText:
                                          //   //     "City for Qurbani service",
                                          // ),
                                          const SizedBox(height: 8),

                                          DropdownButtonFormField<csc.City>(
                                            value: selectedCity,
                                            isExpanded: true,
                                            style: const TextStyle(
                                              color: Colors
                                                  .black, // selected text color
                                              fontSize: 13,
                                            ),
                                            items: cities
                                                .map(
                                                  (c) =>
                                                      DropdownMenuItem<
                                                        csc.City
                                                      >(
                                                        value: c,
                                                        child: Text(c.name),
                                                      ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                selectedCity = value;
                                                cityController.text =
                                                    value?.name ?? '';
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              labelText:
                                                  "City for Qurbani Service",
                                              prefixIcon: Icon(
                                                Icons.location_city,
                                              ),
                                              filled: true,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(12),
                                                ),
                                              ),
                                            ),
                                            validator: (v) {
                                              // If no cities available → allow null
                                              if (cities.isEmpty) return null;

                                              // Cities exist → selection required
                                              if (v == null) {
                                                return "Please select city";
                                              }
                                              return null;
                                            },
                                          ),

                                          const SizedBox(height: 8),

                                          // Postal / Zip Code
                                          _field(
                                            postalCodeController,
                                            "Postal / Zip Code",
                                            Icons.markunread_mailbox,
                                            // helperText: countryISO == 'IN'
                                            //     ? "6-digit PIN code"
                                            //     : "ZIP / Postal code",
                                            validator: _validatePostalCode,
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
                                                  "Qasab",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                              // DropdownMenuItem(
                                              //   value: 'delivery',
                                              //   child: Text(
                                              //     "Delivery",
                                              //     style: TextStyle(
                                              //       color: Colors.black,
                                              //     ),
                                              //   ),
                                              // ),
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
