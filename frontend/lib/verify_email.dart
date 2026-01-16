// import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:Qurbani/authentication/login_page.dart';

// class VerifyEmailPage extends StatefulWidget {
//   final String email;

//   const VerifyEmailPage(this.email, {super.key});

//   @override
//   State<VerifyEmailPage> createState() => _VerifyEmailPageState();
// }

// class _VerifyEmailPageState extends State<VerifyEmailPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   late User? _user;
//   Timer? _timer;
//   bool isLoading = false;
//   bool emailSent = false;

//   @override
//   void initState() {
//     super.initState();
//     _user = _auth.currentUser;
//     _startEmailCheck();
//   }

//   void _startEmailCheck() {
//     _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
//       await _user?.reload();
//       _user = _auth.currentUser;
//       if (_user?.emailVerified ?? false) {
//         _timer?.cancel();
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Email verified! Please login.")),
//         );
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginScreen()),
//         );
//       }
//     });
//   }

//   Future<void> _sendVerificationEmail() async {
//     if (_user == null) return;
//     try {
//       setState(() => isLoading = true);
//       await _user!.sendEmailVerification();
//       setState(() {
//         emailSent = true;
//       });
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Verification email sent")));
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error sending email: $e")));
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFEEF7EF),
//       appBar: AppBar(
//         title: const Text("Verify Email"),
//         backgroundColor: AppTheme.primaryGreen,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.email_outlined,
//               size: 100,
//               color: AppTheme.primaryGreen,
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               "Verify Your Email",
//               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               "A verification link has been sent to your email.\nPlease verify to continue.",
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: isLoading ? null : _sendVerificationEmail,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppTheme.primaryGreen,
//                 padding: const EdgeInsets.symmetric(
//                   vertical: 14,
//                   horizontal: 20,
//                 ),
//               ),
//               child: isLoading
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : Text(
//                       emailSent
//                           ? "Resend Verification Email"
//                           : "Send Verification Email",
//                       style: const TextStyle(fontSize: 16),
//                     ),
//             ),
//             const SizedBox(height: 20),
//             TextButton(
//               onPressed: () {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (_) => const LoginScreen()),
//                 );
//               },
//               child: const Text(
//                 "Back to Login",
//                 style: TextStyle(color: AppTheme.primaryGreen),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
