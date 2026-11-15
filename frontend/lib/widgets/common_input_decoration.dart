import 'package:Qurbani/theme/theme.dart';
import 'package:flutter/material.dart';

class CommonInputDecoration {
  static InputDecoration build(
    String hint, {
    String? label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? primaryColor,
    Color? fillColor,
  }) {
    final color = primaryColor ?? AppTheme.primaryGreen;
    return InputDecoration(
      hintText: hint,
      labelText: label,
      labelStyle: TextStyle(color: color),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor ?? AppTheme.bgGradientEnd,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.warningRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.warningRed, width: 1.5),
      ),
    );
  }
}
