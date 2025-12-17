import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qurbani1/login_page.dart';
import 'package:qurbani1/terms_condition_dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final addressController = TextEditingController();

  String selectedRole = 'user';
  bool termsAccepted = false;
  bool isLoading = false;

  // ---------------- TERMS ----------------
  Future<void> _openTerms() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
    );

    // Only update if the value actually changed
    if (accepted != null && accepted != termsAccepted) {
      setState(() {
        termsAccepted = accepted; // true or false based on user's choice
      });
    }
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
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passController.text.trim(),
          );

      final user = cred.user!;
      await user.sendEmailVerification();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'role': selectedRole,
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration successful! Verify your email."),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already registered";
      if (e.code == 'weak-password') msg = "Password too weak";
      if (e.code == 'invalid-email') msg = "Invalid email";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- FIELD HELPER ----------------
  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: (v) =>
            v == null || v.trim().isEmpty ? "$label required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
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
    passController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF7EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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

                          const SizedBox(height: 15),

                          const Text(
                            'Fresh Qurbani, Delivered to Your Doorstep',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 40),

                          // Fields with same style as login page
                          _field(nameController, "Full Name", Icons.person),
                          _field(
                            emailController,
                            "Email",
                            Icons.email_outlined,
                          ),
                          _field(
                            passController,
                            "Password",
                            Icons.lock_outline,
                            obscure: true,
                          ),
                          _field(
                            addressController,
                            "Address",
                            Icons.location_on_outlined,
                          ),

                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            items: const [
                              DropdownMenuItem(
                                value: 'user',
                                child: Text("User"),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text("Admin"),
                              ),
                              DropdownMenuItem(
                                value: 'delivery',
                                child: Text("Delivery"),
                              ),
                            ],
                            onChanged: (v) => setState(() => selectedRole = v!),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              labelText: "Role",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

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

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Register",
                                      style: TextStyle(fontSize: 18),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Center(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Already have an account? Login",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
