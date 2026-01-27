import 'dart:async';
import 'package:Qurbani/authentication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage(this.email, {super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isLoading = false;
  bool verified = false;
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  @override
  void initState() {
    super.initState();
    // Optionally, start polling to check verification status
    // _startVerificationCheck();
  }

  /// Call backend to manually verify email using token
  Future<void> verifyEmail(String token) async {
    final url = Uri.parse(
      "$_baseUrl/auth/verify-email?token=$token",
    );

    try {
      setState(() => isLoading = true);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() => verified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email verified! You can now login.")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message'] ?? response.body)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error verifying email: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Poll the backend to see if the email is verified (optional)
  // void _startVerificationCheck() {
  //   Timer.periodic(const Duration(seconds: 5), (timer) async {
  //     if (verified) {
  //       timer.cancel();
  //       return;
  //     }

  //     final url = Uri.parse(
  //       "http://0.0.0.0:3000/api/auth/check-email-status?email=${widget.email}",
  //     );
  //     try {
  //       final response = await http.get(url);
  //       if (response.statusCode == 200) {
  //         final body = jsonDecode(response.body);
  //         if (body['is_verified'] == true) {
  //           timer.cancel();
  //           setState(() => verified = true);
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(
  //               content: Text("Email verified! You can now login."),
  //             ),
  //           );
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (_) => const LoginScreen()),
  //           );
  //         }
  //       }
  //     } catch (_) {}
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF7EF),
      appBar: AppBar(
        title: const Text("Verify Email"),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: 100,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 20),
            const Text(
              "Verify Your Email",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "A verification link has been sent to ${widget.email}.\nPlease click the link to verify.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      // This button just tells user to click the link in email
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Check your email for the verification link.",
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Check Email", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text(
                "Back to Login",
                style: TextStyle(color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
