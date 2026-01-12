import 'package:flutter/material.dart';

class CommonInputDecoration {
  static InputDecoration build(String hint, {Color? primaryColor}) {
    final color = primaryColor ?? const Color(0xFF3D6B4E);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      ),
    );
  }
}
