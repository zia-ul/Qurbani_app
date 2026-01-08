// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// //import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

// class ResetPasswordPage extends StatefulWidget {
//   const ResetPasswordPage({super.key});

//   @override
//   State<ResetPasswordPage> createState() => _ResetPasswordPageState();
// }

// class _ResetPasswordPageState extends State<ResetPasswordPage> {
//   final _currentPasswordController = TextEditingController();
//   final _newPasswordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;
//   bool _obscureCurrentPassword = true;
//   bool _obscureNewPassword = true;
//   bool _obscureConfirmPassword = true;

//   Future<void> _changePassword() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         Fluttertoast.showToast(
//           msg: "User not authenticated. Please login again.",
//           toastLength: Toast.LENGTH_LONG,
//           gravity: ToastGravity.BOTTOM,
//           backgroundColor: Colors.red,
//           textColor: Colors.white,
//         );
//         return;
//       }

//       final currentPassword = _currentPasswordController.text.trim();
//       final newPassword = _newPasswordController.text.trim();

//       // Re-authenticate the user with current password
//       final credential = EmailAuthProvider.credential(
//         email: user.email!,
//         password: currentPassword,
//       );

//       await user.reauthenticateWithCredential(credential);

//       // Change the password
//       await user.updatePassword(newPassword);

//       Fluttertoast.showToast(
//         msg: "Password changed successfully!",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: const Color(0xff537D4F),
//         textColor: Colors.white,
//       );

//       // Clear the form fields
//       _currentPasswordController.clear();
//       _newPasswordController.clear();
//       _confirmPasswordController.clear();

//       // Navigate back to settings page
//       Navigator.pop(context);
//     } on FirebaseAuthException catch (e) {
//       String errorMessage = "Failed to change password";

//       switch (e.code) {
//         case 'wrong-password':
//           errorMessage = "Current password is incorrect";
//           break;
//         case 'weak-password':
//           errorMessage =
//               "New password is too weak. Please use a stronger password";
//           break;
//         case 'requires-recent-login':
//           errorMessage = "Please login again and try changing your password";
//           break;
//         case 'user-mismatch':
//           errorMessage = "Authentication error. Please login again";
//           break;
//         default:
//           errorMessage = e.message ?? "An error occurred";
//       }

//       Fluttertoast.showToast(
//         msg: errorMessage,
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//         textColor: Colors.white,
//       );
//     } catch (e) {
//       Fluttertoast.showToast(
//         msg: "An unexpected error occurred",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//         textColor: Colors.white,
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xff537D4F),
//         title: const Text(
//           "Change Password",
//           style: TextStyle(color: Colors.white),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Enter your current password and new password to update your account.",
//                 style: TextStyle(fontSize: 16, color: Color(0xff537D4F)),
//               ),
//               const SizedBox(height: 30),

//               // Current Password Field
//               TextFormField(
//                 controller: _currentPasswordController,
//                 obscureText: _obscureCurrentPassword,
//                 decoration: InputDecoration(
//                   filled: true,
//                   fillColor: Colors.white,
//                   prefixIcon: const Icon(
//                     Icons.lock_outline,
//                     color: Color(0xff537D4F),
//                   ),
//                   labelText: 'Current Password',
//                   labelStyle: const TextStyle(color: Color(0xff537D4F)),
//                   border: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   focusedBorder: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscureCurrentPassword
//                           ? Icons.visibility_off
//                           : Icons.visibility,
//                       color: Color(0xff537D4F),
//                     ),
//                     onPressed: () {
//                       setState(
//                         () =>
//                             _obscureCurrentPassword = !_obscureCurrentPassword,
//                       );
//                     },
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your current password';
//                   }
//                   if (value.length < 6) {
//                     return 'Password must be at least 6 characters';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),

//               // New Password Field
//               TextFormField(
//                 controller: _newPasswordController,
//                 obscureText: _obscureNewPassword,
//                 decoration: InputDecoration(
//                   filled: true,
//                   fillColor: Colors.white,
//                   prefixIcon: const Icon(Icons.lock, color: Color(0xff537D4F)),
//                   labelText: 'New Password',
//                   labelStyle: const TextStyle(color: Color(0xff537D4F)),
//                   border: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   focusedBorder: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscureNewPassword
//                           ? Icons.visibility_off
//                           : Icons.visibility,
//                       color: Color(0xff537D4F),
//                     ),
//                     onPressed: () {
//                       setState(
//                         () => _obscureNewPassword = !_obscureNewPassword,
//                       );
//                     },
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter your new password';
//                   }
//                   if (value.length < 6) {
//                     return 'Password must be at least 6 characters';
//                   }
//                   if (value == _currentPasswordController.text) {
//                     return 'New password must be different from current password';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),

//               // Confirm New Password Field
//               TextFormField(
//                 controller: _confirmPasswordController,
//                 obscureText: _obscureConfirmPassword,
//                 decoration: InputDecoration(
//                   filled: true,
//                   fillColor: Colors.white,
//                   prefixIcon: const Icon(
//                     Icons.lock_outline,
//                     color: Color(0xff537D4F),
//                   ),
//                   labelText: 'Confirm New Password',
//                   labelStyle: const TextStyle(color: Color(0xff537D4F)),
//                   border: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   focusedBorder: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(12)),
//                     borderSide: BorderSide(color: Color(0xff537D4F)),
//                   ),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscureConfirmPassword
//                           ? Icons.visibility_off
//                           : Icons.visibility,
//                       color: Color(0xff537D4F),
//                     ),
//                     onPressed: () {
//                       setState(
//                         () =>
//                             _obscureConfirmPassword = !_obscureConfirmPassword,
//                       );
//                     },
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please confirm your new password';
//                   }
//                   if (value != _newPasswordController.text) {
//                     return 'Passwords do not match';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 40),

//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _changePassword,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 15),
//                     backgroundColor: const Color(0xff537D4F),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(color: Colors.white),
//                         )
//                       : const Text(
//                           "Change Password",
//                           style: TextStyle(fontSize: 16, color: Colors.white),
//                         ),
//                 ),
//               ),
//               const SizedBox(height: 20),

//               const Text(
//                 "Note: Your password must be at least 6 characters long.",
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Color(0xff537D4F),
//                   fontStyle: FontStyle.italic,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
