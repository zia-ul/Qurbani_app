import 'package:flutter/material.dart';

class AppTheme {
  // Core Colors
  static const Color primaryGreen = Color(0xff3D6B4E); // Main brand green
  static const Color accentGreen = Color(
    0xff6B8E5A,
  ); // Softer accent for harmony
  static const Color warningRed = Color(
    0xffD32F2F,
  ); // Softened red for warnings

  // Parchment Gradient
  static const Color bgGradientStart = Color(0xffF2E8D5); // Warm parchment
  static const Color bgGradientEnd = Color(0xffFFFFFF); // Soft white fade

  // Dark Mode Variants
  static const Color darkBgGradientStart = Color(0xff2A2A2A); // Dark parchment
  static const Color darkBgGradientEnd = Color(0xff1E1E1E); // Deep gray fade

  // LIGHT THEME
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Transparent scaffold for gradient overlay
    scaffoldBackgroundColor: Colors.transparent,

    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: accentGreen,
      error: warningRed,
      background: bgGradientEnd, // Base for surfaces
      surface: Colors.white.withOpacity(0.9), // Semi-transparent for depth
      onPrimary: Colors.white, // Text on primary
      onSecondary: Colors.white,
      onSurface: Colors.black87, // Dark text on light BG
      onBackground: Colors.black87,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppTheme.primaryGreen.withOpacity(
        0.9,
      ), // Semi-transparent for gradient feel
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Avoid overlay issues
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryGreen,
        side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.8), // Subtle on parchment
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      labelStyle: const TextStyle(color: AppTheme.primaryGreen),
      hintStyle: const TextStyle(color: Colors.black54),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTheme.primaryGreen,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    cardTheme: CardThemeData(
      color: Colors.white.withOpacity(0.95), // Semi-transparent for parchment
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: AppTheme.primaryGreen.withOpacity(0.1),
    ),

    dividerTheme: const DividerThemeData(color: Colors.black12, thickness: 1),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87), // Default dark text
      bodyMedium: TextStyle(color: Colors.black87),
      headlineSmall: TextStyle(
        color: AppTheme.primaryGreen,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // DARK THEME
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Transparent scaffold for gradient overlay
    scaffoldBackgroundColor: Colors.transparent,

    colorScheme: ColorScheme.dark(
      primary: accentGreen,
      secondary: primaryGreen,
      error: warningRed,
      background: darkBgGradientEnd, // Base for surfaces
      surface: darkBgGradientStart.withOpacity(0.9), // Semi-transparent
      onPrimary: Colors.black, // Text on primary
      onSecondary: Colors.black,
      onSurface: Colors.white70, // Light text on dark BG
      onBackground: Colors.white70,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: darkBgGradientStart.withOpacity(0.9),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentGreen,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentGreen,
        side: const BorderSide(color: accentGreen, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBgGradientStart.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: accentGreen, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      labelStyle: const TextStyle(color: accentGreen),
      hintStyle: const TextStyle(color: Colors.white54),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: accentGreen,
      contentTextStyle: const TextStyle(color: Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    cardTheme: CardThemeData(
      color: darkBgGradientStart.withOpacity(0.95),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: accentGreen.withOpacity(0.1),
    ),

    dividerTheme: const DividerThemeData(color: Colors.white12, thickness: 1),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70), // Default light text
      bodyMedium: TextStyle(color: Colors.white70),
      headlineSmall: TextStyle(color: accentGreen, fontWeight: FontWeight.bold),
    ),
  );

  // 🌈 Background Gradients (Reusable)
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradientStart, bgGradientEnd],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgGradientStart, darkBgGradientEnd],
  );
}
