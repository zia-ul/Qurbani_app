import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qurbani1/login_page.dart';
import 'package:qurbani1/terms_condition_dialog.dart';
import 'package:qurbani1/verify_email.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  String selectedRole = 'user';
  String? selectedGender;
  bool termsAccepted = false;
  bool isLoading = false;
  String passwordStrength = "";

  // ---------------- PASSWORD STRENGTH ----------------
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
    if (!_formKey.currentState!.validate()) return;

    if (!termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept Terms & Conditions")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );

      final user = cred.user!;
      await user.sendEmailVerification();

      final roleToSave = selectedRole == 'admin' ? 'pending_admin' : selectedRole;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': roleToSave,
        'gender': selectedGender,
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage(user.email!)),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Registration failed";
      if (e.code == 'email-already-in-use') message = "Email already registered";
      else if (e.code == 'weak-password') message = "Password too weak";
      else if (e.code == 'invalid-email') message = "Invalid email";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- FIELD ----------------
  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    String? helperText,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        keyboardType: label == "Phone Number"
            ? TextInputType.phone
            : TextInputType.text,
        validator:
            validator ?? (v) => v == null || v.trim().isEmpty ? "$label is required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          helperText: helperText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: Icon(icon, color: Colors.green),
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
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF7EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fresh Qurbani, Delivered to Your Doorstep",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                _field(nameController, "Full Name", Icons.person),
                const SizedBox(height: 4),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => selectedGender = v),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: "Gender",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (v) => v == null ? "Please select gender" : null,
                ),
                const SizedBox(height: 12),

                _field(
                  emailController,
                  "Email",
                  Icons.email_outlined,
                  validator: (v) => v!.contains("@") ? null : "Invalid email",
                ),
                const SizedBox(height: 4),

                _field(
                  phoneController,
                  "Phone Number",
                  Icons.phone,
                  validator: (v) => v != null && v.length >= 10
                      ? null
                      : "Enter valid phone number",
                ),
                const SizedBox(height: 4),

                _field(
                  passController,
                  "Password",
                  Icons.lock_outline,
                  obscure: true,
                  helperText:
                      "Min 8 chars, 1 upper, 1 lower, 1 number, 1 special\nExample: Abc@1234",
                  onChanged: (v) {
                    setState(() {
                      passwordStrength = _checkPasswordStrength(v);
                    });
                  },
                  validator: (v) => _isPasswordValid(v!)
                      ? null
                      : "Password does not meet requirements",
                ),
                const SizedBox(height: 4),

                _field(
                  confirmPassController,
                  "Confirm Password",
                  Icons.lock_outline,
                  obscure: true,
                  validator: (v) => v != passController.text
                      ? "Passwords do not match"
                      : null,
                ),
                

                if (passwordStrength.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Password strength: $passwordStrength",
                      style: TextStyle(
                        color: passwordStrength == "Strong"
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),

                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text("User")),
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'delivery', child: Text("Delivery")),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: "Register As",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    Checkbox(
                      value: termsAccepted,
                      onChanged: (_) => _openTerms(),
                      activeColor: Colors.green,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _openTerms,
                        child: const Text(
                          "I agree to the Terms & Conditions",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register", style: TextStyle(fontSize: 18)),
                ),

                const SizedBox(height: 15),

                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    "Already have an account? Login",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
