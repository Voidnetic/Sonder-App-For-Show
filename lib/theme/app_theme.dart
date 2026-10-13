import 'package:flutter/material.dart';

class AppTheme {
  // Base Colors
  static const Color kBackground = Color(0xFFFAF9F6); // Warm off-white
  static const Color kTextPrimary = Color(0xFF1C1C1C); // Dark charcoal
  static const Color kTextSecondary = Color(0xFF6B6B6B);
  static const Color kBorder = Color(0xFF2D2D2D);

  // Pastels
  static const Color kLavender = Color(0xFFE6E6FA);
  static const Color kPaleYellow = Color(0xFFFFFACD);
  static const Color kSoftMint = Color(0xFFE0F8E6);
  static const Color kPalePeach = Color(0xFFFFE5B4);
  static const Color kLightBlue = Color(0xFFE1F5FE);

  // Matches the theme the original prototype ran with. Don't give bodyMedium a colour here:
  // it's the default style for every Text, so it would turn all unstyled text grey.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBackground,
      primaryColor: kTextPrimary,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: kTextPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      ),
    );
  }
}
