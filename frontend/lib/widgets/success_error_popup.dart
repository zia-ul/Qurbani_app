import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum ToastType { success, error }

class ToastUtils {
  // Private constructor to prevent instantiation
  ToastUtils._();

  // Show success toast (green)
  static void showSuccess(String message) {
    _showToast(message, ToastType.success);
  }

  // Show error toast (red)
  static void showError(String message) {
    _showToast(message, ToastType.error);
  }

  // Private method to handle toast display
  static void _showToast(String message, ToastType type) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT, // Duration: short (2-3 seconds)
      gravity: ToastGravity.BOTTOM, // Position: bottom of screen
      timeInSecForIosWeb: 1, // iOS/Web duration
      backgroundColor: type == ToastType.success ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}